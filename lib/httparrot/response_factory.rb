require 'ostruct'
require 'erb'
require 'active_support/core_ext/numeric'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/string/inflections'

module HTTParrot

  class Widget < OpenStruct

    def parent(parental_class, defaults={})
      case
      when parental_class.is_a?(Symbol) then
        parental_class = HTTParrot::ResponseFactory.build(parental_class, defaults)
      end

      self.marshal_load(parental_class.marshal_dump)
    end

    def contains_many(relation_class, build_one = false, options={})
      self.send("#{relation_class.to_s.pluralize}=", [])
    end

    def options
      return @table
    end

    def rack_response(response_code = 200)
      # should probably set some headers here
      rendered_response = self.to_s
      return [response_code, {"Content-Length" => rendered_response.size.to_s}, [rendered_response]]
    end
    alias_method :to_rack, :rack_response

    def to_s
      if @table.has_key?(:template_file)
        file_template = File.dirname(File.expand_path(__FILE__)) 
        file_template = file_template + "/" + template_file
        file_string = File.read(file_template)

        current_template = ERB.new(file_string, nil, "<>")
        return current_template.result(binding) 
      end

      return self.inspect
    end

  end

  class ResponseFactory

    class << self

      def clear!
        @factory_classes = {}
      end

      def define(factory_class, &block)
        @factory_classes ||= {} 
        default_object = HTTParrot::Widget.new(:class => "Widget::#{factory_class.to_s.camelize}")
        @factory_classes[factory_class] = lambda{ block.call(default_object); default_object } 
      end

      def build(factory_class, new_options={})
        raise error_for_missing(factory_class) if @factory_classes[factory_class].nil?
        object = @factory_classes[factory_class].call

        new_options.each do |k, v|
          object.send("#{k}=", v) 
        end

        return Marshal.load(Marshal.dump(object)) 
      end

      def collection_of(factory_class, number, new_options={})
        collection = []

        number.times do 
          collection << build(factory_class, new_options)
        end

        return collection
      end

      def one_of(choices)
        choices[rand(choices.size)]
      end

      private 

      def error_for_missing(factory_class)
        "Unknown factory type: #{factory_class} in known factories: #{@factory_classes.keys}"
      end

    end

  end

end
