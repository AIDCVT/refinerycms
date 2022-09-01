module Refinery
  module Core
    class Engine < ::Rails::Engine
      extend Refinery::Engine

      isolate_namespace Refinery
      engine_name :refinery

      class << self
        # Performs the Refinery inclusion process which extends the currently loaded Rails
        # applications with Refinery's controllers and helpers. The process is wrapped by
        # a before_inclusion and after_inclusion step that calls procs registered by the
        # Refinery::Engine#before_inclusion and Refinery::Engine#after_inclusion class methods
        def refinery_inclusion!
          before_inclusion_procs.each(&:call).tap do |c|
            c.clear if Rails.application.config.cache_classes
          end

          Refinery.include_once(::ApplicationController, Refinery::ApplicationController)
          ::ApplicationController.send :helper, Refinery::Core::Engine.helpers

          after_inclusion_procs.each(&:call).tap do |c|
            c.clear if Rails.application.config.cache_classes
          end

          # Register all decorators from app/decorators/ and registered plugins' paths.
          Decorators.register! Rails.root, Refinery::Plugins.registered.pathnames
        end
      end

      config.autoload_paths += %W( #{config.root}/lib )

      # Include the refinery controllers and helpers dynamically
      config.to_prepare(&method(:refinery_inclusion!).to_proc)

      # Wrap errors in spans
      config.to_prepare do
        ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
          ActionController::Base.helpers.content_tag(:span, html_tag, class: "fieldWithErrors")
        end
      end

      initializer "refinery.will_paginate" do
        WillPaginate.per_page = 20
      end

      initializer "refinery.mobility" do
        Mobility.configure do
          plugins do
            # Backend
            #
            # Sets the default backend to use in models. This can be overridden in models
            # by passing +backend: ...+ to +translates+.
            #
            # To default to a different backend globally, replace +:key_value+ by another
            # backend name.
            #
            backend :table

            # ActiveRecord
            #
            # Defines ActiveRecord as ORM, and enables ActiveRecord-specific plugins.
            active_record

            # Accessors
            #
            # Define reader and writer methods for translated attributes. Remove either
            # to disable globally, or pass +reader: false+ or +writer: false+ to
            # +translates+ in any translated model.
            #
            reader
            writer

            # Backend Reader
            #
            # Defines reader to access the backend for any attribute, of the form
            # +<attribute>_backend+.
            #
            backend_reader
            #
            # Or pass an interpolation string to define a different pattern:
            # backend_reader "%s_translations"

            # Query
            #
            # Defines a scope on the model class which allows querying on
            # translated attributes. The default scope is named +i18n+, pass a different
            # name as default to change the global default, or to +translates+ in any
            # model to change it for that model alone.
            #
            query

            # Cache
            #
            # Comment out to disable caching reads and writes.
            #
            cache

            # Dirty
            #
            # Uncomment this line to include and enable globally:
            # dirty
            #
            # Or uncomment this line to include but disable by default, and only enable
            # per model by passing +dirty: true+ to +translates+.
            # dirty false

            # Fallbacks
            #
            # Uncomment line below to enable fallbacks, using +I18n.fallbacks+.
            # fallbacks
            #
            # Or uncomment this line to enable fallbacks with a global default.
            # fallbacks { :pt => :en }

            # Presence
            #
            # Converts blank strings to nil on reads and writes. Comment out to
            # disable.
            #
            presence

          end
        end
      end

      before_inclusion do
        Refinery::Plugin.register do |plugin|
          plugin.pathname = root
          plugin.name = 'refinery_core'
          plugin.class_name = 'RefineryEngine'
          plugin.hide_from_menu = true
          plugin.always_allow_access = true
          plugin.menu_match = /refinery\/(refinery_)?core$/
        end

        Refinery::Plugin.register do |plugin|
          plugin.pathname = root
          plugin.name = 'refinery_dialogs'
          plugin.hide_from_menu = true
          plugin.always_allow_access = true
          plugin.menu_match = /refinery\/(refinery_)?dialogs/
        end
      end

      initializer "refinery.routes" do |app|
        Refinery::Core::Engine.routes.append do
          get "#{Refinery::Core.backend_route}/*path" => 'admin#error_404'
        end
      end

      initializer "refinery.autoload_paths" do |app|
        app.config.autoload_paths += [
          Rails.root.join('app', 'presenters'),
          Rails.root.join('vendor', '**', '**', 'app', 'presenters'),
          Refinery.roots.map{ |r| r.join('**', 'app', 'presenters')}
        ].flatten
      end

      # active model fields which may contain sensitive data to filter
      initializer "refinery.params.filter" do |app|
        app.config.filter_parameters += [:password, :password_confirmation]
      end

      initializer "refinery.encoding" do |app|
        app.config.encoding = 'utf-8'
      end

      initializer "refinery.memory_store" do |app|
        app.config.cache_store = :memory_store
      end

      config.after_initialize do
        Refinery.register_extension(Refinery::Core)
      end
    end
  end
end
