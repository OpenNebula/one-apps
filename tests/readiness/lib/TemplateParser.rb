###############################################################################
# The TemplateParser Class parses a VM template file and builds a hash with
# the info. It does not check syntax.
###############################################################################
class TemplateParser
    ##########################################################################
    # Patterns to parse the template File
    ##########################################################################

    NAME_REG     =/[\w\d_-]+/
    VARIABLE_REG =/\s*(#{NAME_REG})\s*=\s*/

    SIMPLE_VARIABLE_REG =/#{VARIABLE_REG}([^\[]+?)(#.*)?/
    SINGLE_VARIABLE_REG =/^#{SIMPLE_VARIABLE_REG}$/
    ARRAY_VARIABLE_REG  =/^#{VARIABLE_REG}\[(.*?)\]/m

    ##########################################################################
    ##########################################################################

    def initialize(template_string)
        @conf=parse_conf(template_string)
    end

    def add_configuration_value(key,value)
        add_value(@conf,key,value)
    end

    def [](key)
        @conf[key.to_s.upcase]
    end

    def hash
        @conf
    end

    def self.template_like_str(attributes, indent=true)
         if indent
             ind_enter="\n"
             ind_tab='  '
         else
             ind_enter=''
             ind_tab=' '
         end

         str=attributes.collect do |key, value|
             if value
                 str_line=""
                 if value.class==Array

                     value.each do |value2|
                         str_line << key.to_s.upcase << "=[" << ind_enter
                         if value2 && value2.class==Hash
                             str_line << value2.collect do |key3, value3|
                                 str = ind_tab + key3.to_s.upcase + "="
                                 str += "\"#{value3.to_s}\"" if value3
                                 str
                             end.compact.join(",\n")
                         end
                         str_line << "\n]\n"
                     end

                 elsif value.class==Hash
                     str_line << key.to_s.upcase << "=[" << ind_enter

                     str_line << value.collect do |key3, value3|
                         str = ind_tab + key3.to_s.upcase + "="
                         str += "\"#{value3.to_s}\"" if value3
                         str
                     end.compact.join(",\n")

                     str_line << "\n]\n"

                 else
                     str_line<<key.to_s.upcase << "=" << "\"#{value.to_s}\""
                 end
                 str_line
             end
         end.compact.join("\n")

         str
     end

    ##########################################################################
    ##########################################################################

private


    def san_key(key)
        key.strip.downcase.to_sym
    end

    def san_value(value)
        value.strip.gsub(/"/, '') if value
    end

    #
    #
    #
    def add_value(conf, key, value)
        if conf[key]
            if !conf[key].kind_of?(Array)
                conf[key]=[conf[key]]
            end
            conf[key] << value
        else
            conf[key] = value
        end
    end

    #
    # Parses the configuration file and
    # creates the configuration hash
    #
    def parse_conf(template_string)
        conf=Hash.new

        template_string.scan(SINGLE_VARIABLE_REG) {|m|
            key=san_key(m[0])
            value=san_value(m[1])

            add_value(conf, key, value)
        }

        template_string.scan(ARRAY_VARIABLE_REG) {|m|
            master_key=san_key(m[0])

            pieces=m[1].split(',')

            vars=Hash.new
            pieces.each {|p|
                key, value=p.split('=')
                vars[san_key(key)]=san_value(value)
            }

            add_value(conf, master_key, vars)
        }

        conf
    end
end
