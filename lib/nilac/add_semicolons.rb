  def add_semicolons(input_file_contents)

    def comment(input_string)

      if input_string.strip.split("--single_line_comment")[0].eql?("")

        true

      elsif input_string.strip.split("--multiline_comment")[0].eql?("")

        true

      else

        false

      end

    end

    input_file_contents = input_file_contents.collect {|element| element.gsub("#iggggnnnore ","")}

    reject_regexp = /(function |Euuf |if |else|elsuf|switch |case|while |whaaleskey |for )/

    modified_file_contents = input_file_contents.dup

    input_file_contents.each_with_index do |line,index|

      if line.index(reject_regexp) == nil

        if !comment(line)

          if !line.lstrip.eql?("")

            if !line.lstrip.eql?("}\n") and !line.strip.eql?("}#@$")

              if !line.lstrip.eql?("}\n\n")

                if line.rstrip[-1] != "[" and line.rstrip[-1] != "{" and line.rstrip[-1] != "," and line.rstrip[-1] != ";"

                  line,comment = line.split("--single_line_comment")

                  unless comment.nil? or comment.strip == ""

                    modified_file_contents[index] = line.rstrip + "; --single_line_comment#{comment}\n\n"

                  else

                    modified_file_contents[index] = line.rstrip + ";\n\n"

                  end

                end

              end

            end

          end

        end

      end

    end

    modified_file_contents

  end