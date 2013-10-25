require_relative 'read_file_line_by_line'
  
  def compile_blocks(input_file_contents,temporary_nila_file)

    def compile_one_line_blocks(input_block)

      block_parameters, block_contents = input_block[1...-1].split("|",2)[1].split("|",2)

      compiled_block = "function(#{block_parameters.lstrip.rstrip}) {\n\n  #{block_contents.strip} \n\n}"

      return compiled_block

    end

    input_file_contents = input_file_contents.collect {|element| element.gsub("append","appand")}

    possible_blocks = input_file_contents.reject {|line| !line.include?(" do ")}

    unless possible_blocks.empty?

      possible_blocks.each do |starting_line|

        index_counter = starting_counter = input_file_contents.index(starting_line)

        line = starting_line

        until line.strip.eql?("end") or line.strip.eql?("end)")

          index_counter += 1

          line = input_file_contents[index_counter]

        end

        loop_extract = input_file_contents[starting_counter..index_counter]

        loop_condition, block = loop_extract.join.split(" do ")

        block = block.split("end")[0]

        replacement_string = "#{loop_condition.rstrip} blockky {#{block.strip}}_!"

        input_file_contents[starting_counter..index_counter] = replacement_string

      end

    end

    possible_blocks = input_file_contents.reject{ |element| !element.include?(" blockky ")}

    possible_blocks = possible_blocks.reject {|element| !element.include?("{") and !element.include?("}")}

    modified_file_contents = input_file_contents.clone

    unless possible_blocks.empty?

      possible_blocks.each do |loop|

        original_loop = loop.clone

        string_counter = 1

        extracted_string = []

        while loop.include?("\"")

          string_extract = loop[loop.index("\"")..loop.index("\"",loop.index("\"")+1)]

          extracted_string << string_extract

          loop = loop.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

        block_extract = loop[loop.index("{")..loop.index("}_!")]

        compiled_block = ""

        if block_extract.count("|") == 2

          compiled_block = compile_one_line_blocks(block_extract)

          extracted_string.each_with_index do |string,index|

            compiled_block = compiled_block.sub("--repstring#{index+1}",string)

          end

        else

          compiled_block = block_extract[1...-1].lstrip.rstrip

          extracted_string.each_with_index do |string,index|

            compiled_block = compiled_block.sub("--repstring#{index+1}",string)

          end

        end

        caller_func = loop.split(" blockky ")[0]

        unless caller_func.rstrip[-1] == ","

          replacement_string = "#{caller_func.rstrip}(#{compiled_block.lstrip})"

        else

          caller_func_split = caller_func.split("(") if caller_func.include?("(")

          caller_func_split = caller_func.split(" ",2) if caller_func.include?(" ")

          replacement_string = "#{caller_func_split[0]}(#{caller_func_split[1].strip + compiled_block.lstrip})"

        end

        modified_file_contents[input_file_contents.index(original_loop)] = replacement_string

      end

    end

    modified_file_contents = modified_file_contents.collect {|element| element.gsub("appand","append")}

    file_id = open(temporary_nila_file, 'w')

    file_id.write(modified_file_contents.join)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    return line_by_line_contents

  end