# all taken from Spree gem
# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/core_ext/hash/keys'

module Plugins
  module Models
    module Concerns
      module Preferences

        # Plugins::Models::Concerns::Preferences::Encryptor is a thin wrapper around ActiveSupport::MessageEncryptor.
        class Encryptor
          # @param key [String] the 256 bits signature key
          def initialize(key)
            @crypt = ActiveSupport::MessageEncryptor.new(key)
          end

          # Encrypt a value
          # @param value [String] the value to encrypt
          # @return [String] the encrypted value
          def encrypt(value)
            @crypt.encrypt_and_sign(value)
          end

          # Decrypt an encrypted value
          # @param encrypted_value [String] the value to decrypt
          # @return [String] the decrypted value
          def decrypt(encrypted_value)
            @crypt.decrypt_and_verify(encrypted_value)
          end
        end

        module PreferableClassMethods
          DEFAULT_ADMIN_FORM_PREFERENCE_TYPES = %i(
            boolean
            decimal
            integer
            password
            string
            text
            encrypted_string
          )

          def defined_preferences
            []
          end

          def preference(name, type, options = {})
            options.assert_valid_keys(:default, :encryption_key)

            if type == :encrypted_string
              preference_encryptor = preference_encryptor(options)
              options[:default] = preference_encryptor.encrypt(options[:default])
            end

            default = begin
                        given = options[:default]
                        if given.is_a?(Proc)
                          given
                        else
                          proc { given }
                        end
                      end

            # The defined preferences on a class are all those defined directly on
            # that class as well as those defined on ancestors.
            # We store these as a class instance variable on each class which has a
            # preference. super() collects preferences defined on ancestors.
            singleton_preferences = (@defined_singleton_preferences ||= [])
            singleton_preferences << name.to_sym

            define_singleton_method :defined_preferences do
              super() + singleton_preferences
            end

            # cache_key will be nil for new objects, then if we check if there
            # is a pending preference before going to default
            define_method preference_getter_method(name) do
              value = preferences.fetch(name) do
                instance_exec(*context_for_default, &default)
              end
              value = preference_encryptor.decrypt(value) if preference_encryptor.present?
              value
            end

            define_method preference_setter_method(name) do |value|
              value = convert_preference_value(value, type, preference_encryptor)
              preferences[name] = value

              # If this is an activerecord object, we need to inform
              # ActiveRecord::Dirty that this value has changed, since this is an
              # in-place update to the preferences hash.
              preferences_will_change! if respond_to?(:preferences_will_change!)
            end

            define_method preference_default_getter_method(name) do
              instance_exec(*context_for_default, &default)
            end

            define_method preference_type_getter_method(name) do
              type
            end
          end

          def preference_getter_method(name)
            "preferred_#{name}".to_sym
          end

          def preference_setter_method(name)
             "preferred_#{name}=".to_sym
          end

          def preference_default_getter_method(name)
            "preferred_#{name}_default".to_sym
          end

          def preference_type_getter_method(name)
            "preferred_#{name}_type".to_sym
          end

          def preference_encryptor(options)
            key = options[:encryption_key] ||
                  ENV['SOLIDUS_PREFERENCES_MASTER_KEY'] ||
                  Rails.application.credentials.secret_key_base

            Plugins::Models::Concerns::Preferences::Encryptor.new(key)
          end

          # List of preference types allowed as form fields in the Solidus admin
          #
          # Overwrite this method in your class that includes +Plugins::Models::Concerns::Preferences::Preferable+
          # if you want to provide more fields. If you do so, you also need to provide
          # a preference field partial that lives in:
          #
          # +app/views/spree/admin/shared/preference_fields/+
          #
          # @return [Array]
          def allowed_admin_form_preference_types
            DEFAULT_ADMIN_FORM_PREFERENCE_TYPES
          end
        end

        # Preferable allows defining preference accessor methods.
        #
        # A class including Preferable must implement #preferences which should return
        # an object responding to .fetch(key), []=(key, val), and .delete(key).
        # If #preferences is initialized with `default_preferences` and one of the
        # preferences is another preference, it will cause a stack level too deep error.
        # To avoid it do not memoize #preferences.
        #
        # It may also define a `#context_for_default` method. It should return an
        # array with the arguments to be provided to a proc used as the `default:`
        # keyword for a preference.
        #
        # The generated writer method performs typecasting before assignment into the
        # preferences object.
        #
        # Examples:
        #
        #   # Plugins::Models::Concerns::Preferences::Base includes Preferable and defines preferences as a serialized
        #   # column.
        #   class Settings < Plugins::Models::Concerns::Preferences::Base
        #     preference :color,       :string,  default: 'red'
        #     preference :temperature, :integer, default: 21
        #   end
        #
        #   s = Settings.new
        #   s.preferred_color # => 'red'
        #   s.preferred_temperature # => 21
        #
        #   s.preferred_color = 'blue'
        #   s.preferred_color # => 'blue'
        #
        #   # Typecasting is performed on assignment
        #   s.preferred_temperature = '24'
        #   s.preferred_color # => 24
        #
        #   # Modifications have been made to the .preferences hash
        #   s.preferences #=> {color: 'blue', temperature: 24}
        #
        #   # Save the changes. All handled by activerecord
        #   s.save!
        #
        # Each preference gets rendered as a form field in Solidus backend.
        #
        # As not all supported preference types are representable as a form field, only
        # some of them get rendered per default. Arrays and Hashes for instance are
        # supported preference field types, but do not represent well as a form field.
        #
        # Overwrite +allowed_admin_form_preference_types+ in your class if you want to
        # provide more fields. If you do so, you also need to provide a preference field
        # partial that lives in:
        #
        # +app/views/spree/admin/shared/preference_fields/+
        #
        module Preferable
          extend ActiveSupport::Concern

          included do
            extend Plugins::Models::Concerns::Preferences::PreferableClassMethods
          end

          # Get a preference
          # @param name [#to_sym] name of preference
          # @return [Object] The value of preference +name+
          def get_preference(name)
            has_preference! name
            send self.class.preference_getter_method(name)
          end

          # Set a preference
          # @param name [#to_sym] name of preference
          # @param value [Object] new value for preference +name+
          def set_preference(name, value)
            has_preference! name
            send self.class.preference_setter_method(name), value
          end

          # @param name [#to_sym] name of preference
          # @return [Symbol] The type of preference +name+
          def preference_type(name)
            has_preference! name
            send self.class.preference_type_getter_method(name)
          end

          # @param name [#to_sym] name of preference
          # @return [Object] The default for preference +name+
          def preference_default(name)
            has_preference! name
            send self.class.preference_default_getter_method(name)
          end

          # Raises an exception if the +name+ preference is not defined on this class
          # @param name [#to_sym] name of preference
          def has_preference!(name)
            raise NoMethodError.new "#{name} preference not defined" unless has_preference? name
          end

          # @param name [#to_sym] name of preference
          # @return [Boolean] if preference exists on this class
          def has_preference?(name)
            defined_preferences.include?(name.to_sym)
          end

          # @return [Array<Symbol>] All preferences defined on this class
          def defined_preferences
            self.class.defined_preferences
          end

          # @return [Hash{Symbol => Object}] Default for all preferences defined on this class
          # This may raise an infinite loop error if any of the defaults are
          # dependent on other preferences defaults.
          def default_preferences
            Hash[
              defined_preferences.map do |preference|
                [preference, preference_default(preference)]
              end
            ]
          end

          # Preference names representable as form fields in Solidus backend
          #
          # Not all preferences are representable as a form field.
          #
          # Arrays and Hashes for instance are supported preference field types,
          # but do not represent well as a form field.
          #
          # As these kind of preferences are mostly developer facing
          # and not admin facing we should not render them.
          #
          # Overwrite +allowed_admin_form_preference_types+ in your class that
          # includes +Plugins::Models::Concerns::Preferences::Preferable+ if you want to provide more fields.
          # If you do so, you also need to provide a preference field partial
          # that lives in:
          #
          # +app/views/spree/admin/shared/preference_fields/+
          #
          # @return [Array]
          def admin_form_preference_names
            defined_preferences.keep_if do |type|
              preference_type(type).in? self.class.allowed_admin_form_preference_types
            end
          end

          private

          def convert_preference_value(value, type, preference_encryptor = nil)
            return nil if value.nil?
            case type
            when :string, :text
              value.to_s
            when :encrypted_string
              preference_encryptor.encrypt(value.to_s)
            when :password
              value.to_s
            when :decimal
              begin
                value.to_s.to_d
              rescue ArgumentError
                BigDecimal(0)
              end
            when :integer
              value.to_i
            when :boolean
              if !value ||
                  value.to_s =~ /\A(f|false|0|^)\Z/i ||
                  (value.respond_to?(:empty?) && value.empty?)
                false
              else
                true
              end
            when :array
              raise TypeError, "Array expected got #{value.inspect}" unless value.is_a?(Array)
              value
            when :hash
              raise TypeError, "Hash expected got #{value.inspect}" unless value.is_a?(Hash)
              value
            else
              value
            end
          end

          def context_for_default
            [].freeze
          end
        end

        def self.included base
          base.extend ClassMethods
        end

        module ClassMethods
          def use_preferences!
            include UsePreferences
          end
        end

        module UsePreferences
          extend ActiveSupport::Concern

          included do
            include Plugins::Models::Concerns::Preferences::Preferable

            if method(:serialize).parameters.include?([:key, :type]) # Rails 7.1+
              serialize :preferences, type: Hash, coder: YAML
            else
              serialize :preferences, Hash, coder: YAML
            end

            after_initialize :initialize_preference_defaults
          end

          private

          def initialize_preference_defaults
            if has_attribute?(:preferences)
              self.preferences = default_preferences.merge(preferences)
            end
          end

        end

      end
    end
  end
end
