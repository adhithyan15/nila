#Nilac is the official Nila compiler. It compiles Nila into pure Javascript. Nilac is currently
#written in Ruby but will be self hosted in the upcoming years.

#Nila and Nilac are being crafted by Adhithya Rajasekaran and Sri Madhavi Rajasekaran

require 'slop'
require 'fileutils'

# The following are error classes used by Nilac to give you detailed error information

class ParseError < RuntimeError

  def initialize(message)

    puts "ParseError: " + message

    abort

  end

end


def compile(input_file_path, *output_file_name)

  def read_file_line_by_line(input_path)

    file_id = open(input_path)

    file_line_by_line = file_id.readlines()

    file_id.close

    return file_line_by_line

  end

  def extract_parsable_file(input_file_contents)

    reversed_file_contents = input_file_contents.reverse

    line_counter = 0

    if input_file_contents.join.include?("__END__")

      while !reversed_file_contents[line_counter].strip.include?("__END__")

        line_counter += 1

      end

      return_contents = input_file_contents[0...-1*line_counter-1]

    else

      input_file_contents

    end

  end

  def replace_multiline_comments(input_file_contents, nila_file_path, *output_js_file_path)

    #This method will replace both the single and multiline comments
    #
    #Single line comment will be replaced by => --single_line_comment[n]
    #
    #Multiline comment will be replaced by => --multiline_comment[n]

    def find_all_matching_indices(input_string, pattern)

      locations = []

      index = input_string.index(pattern)

      while index != nil

        locations << index

        index = input_string.index(pattern, index+1)


      end

      return locations


    end

    def find_file_path(input_path, file_extension)

      extension_remover = input_path.split(file_extension)

      remaining_string = extension_remover[0].reverse

      path_finder = remaining_string.index("/")

      remaining_string = remaining_string.reverse

      return remaining_string[0...remaining_string.length-path_finder]

    end

    def find_file_name(input_path, file_extension)

      extension_remover = input_path.split(file_extension)

      remaining_string = extension_remover[0].reverse

      path_finder = remaining_string.index("/")

      remaining_string = remaining_string.reverse

      return remaining_string[remaining_string.length-path_finder..-1]

    end

    multiline_comments = []

    file_contents_as_string = input_file_contents.join

    modified_file_contents = file_contents_as_string.dup

    multiline_comment_counter = 1

    multiline_comments_start = find_all_matching_indices(file_contents_as_string, "=begin")

    multiline_comments_end = find_all_matching_indices(file_contents_as_string, "=end")

    for y in 0...multiline_comments_start.length

      start_of_multiline_comment = multiline_comments_start[y]

      end_of_multiline_comment = multiline_comments_end[y]

      multiline_comment = file_contents_as_string[start_of_multiline_comment..end_of_multiline_comment+3]

      modified_file_contents = modified_file_contents.gsub(multiline_comment, "--multiline_comment[#{multiline_comment_counter}]\n\n")

      multiline_comment_counter += 1

      multiline_comments << multiline_comment


    end

    temporary_nila_file = find_file_path(nila_file_path, ".nila") + "temp_nila.nila"

    if output_js_file_path.empty?

      output_js_file = find_file_path(nila_file_path, ".nila") + find_file_name(nila_file_path, ".nila") + ".js"

    else

      output_js_file = output_js_file_path[0]

    end

    file_id = open(temporary_nila_file, 'w')

    file_id2 = open(output_js_file, 'w')

    file_id.write(modified_file_contents)

    file_id.close()

    file_id2.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    comments = multiline_comments.dup

    return line_by_line_contents, comments, temporary_nila_file, output_js_file

  end

  def split_semicolon_seperated_expressions(input_file_contents)

    modified_file_contents = input_file_contents.dup

    input_file_contents.each_with_index do |line, index|

      if line.include?("\"")

        first_index = line.index("\"")

        modified_line = line.sub(line[first_index..line.index("\"", first_index+1)], "--string")

      elsif line.include?("'")

        first_index = line.index("'")

        modified_line = line.sub(line[first_index..line.index("'", first_index+1)], "--string")

      else

        modified_line = line

      end

      if modified_line.include?(";")

        replacement_line = modified_file_contents[index]

        replacement_line = replacement_line.split(";").join("\n\n") + "\n"

        modified_file_contents[index] = replacement_line

      end

    end

    return modified_file_contents

  end

  def compile_heredocs(input_file_contents, temporary_nila_file)

    joined_file_contents = input_file_contents.join

    possible_heredocs = input_file_contents.reject { |element| !element.include?("<<-") }

    possible_heredocs = possible_heredocs.collect { |element| element.match(/<<-(.*|\w*)/).to_a[0] }

    possible_heredocs.each do |heredoc|

      delimiter = heredoc[3..-1]

      quote = 2

      if delimiter.include?("'")

        quote = 1

      end

      delimiter = delimiter.gsub("\"", "") if quote == 2

      delimiter = delimiter.gsub("'", "") if quote == 1

      string_split = joined_file_contents.split(heredoc, 2)

      string_extract = string_split[1]

      heredoc_extract = string_extract[0...string_extract.index(delimiter)]

      replacement_string = ""

      if quote == 1

        replacement_string = "'#{heredoc_extract.delete("\"")}'".lstrip.inspect

        replacement_string = replacement_string[1..-2]

      elsif quote == 2

        replacement_string = heredoc_extract.lstrip.inspect

      end

      joined_file_contents = joined_file_contents.sub(heredoc + heredoc_extract + delimiter, replacement_string)

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(joined_file_contents)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    return line_by_line_contents


  end

  def compile_interpolated_strings(input_file_contents)

    def find_all_matching_indices(input_string, pattern)

      locations = []

      index = input_string.index(pattern)

      while index != nil

        locations << index

        index = input_string.index(pattern, index+1)


      end

      return locations


    end

    modified_file_contents = input_file_contents.dup

    single_quoted_strings = input_file_contents.reject { |element| !(element.count("'") >= 2) }

    single_quoted_strings.each do |str|

      modified_string = str.dup

      while modified_string.include?("'")

        first_index = modified_string.index("'")

        string_extract = modified_string[first_index..modified_string.index("'", first_index+1)]

        modified_string = modified_string.sub(string_extract, "--single_quoted")

      end

      input_file_contents[input_file_contents.index(str)] = modified_string

    end

    input_file_contents.each_with_index do |line, index|

      if line.include?("\#{")

        modified_line = line.dup

        interpol_starting_loc = find_all_matching_indices(modified_line, "\#{") + [-1]

        interpolated_strings = []

        until interpol_starting_loc.empty?

          interpol_starting_loc[1] = -2 if interpol_starting_loc[1] == -1

          string_extract = modified_line[interpol_starting_loc[0]+1..interpol_starting_loc[1]+1]

          closed_curly_brace_index = find_all_matching_indices(string_extract, "}")

          index_counter = 0

          test_string = ""

          until closed_curly_brace_index.empty?

            test_string = string_extract[0..closed_curly_brace_index[0]]

            original_string = test_string.dup

            if test_string.include?("{")

              test_string = test_string.reverse.sub("{", "$#{index_counter}$").reverse

              test_string[-1] = "@#{index_counter}@"

            end

            string_extract = string_extract.sub(original_string, test_string)

            closed_curly_brace_index = find_all_matching_indices(string_extract, "}")

            index_counter += 1

          end

          string_extract = string_extract[0..string_extract.length-string_extract.reverse.index(/@\d@/)]

          interpolated_string = "\#{" + string_extract.split("@#{index_counter-1}@")[0].split("$#{index_counter-1}$")[1] + "}"

          to_be_replaced = interpolated_string.scan(/\$\d\$/)

          closing_brace_rep = interpolated_string.scan(/@\d@/)

          to_be_replaced.each_with_index do |rep, index|

            interpolated_string = interpolated_string.sub(rep, "{").sub(closing_brace_rep[index], "}")

          end

          interpolated_strings << interpolated_string

          modified_line = modified_line.sub(interpolated_string, "--interpolate")

          if find_all_matching_indices(modified_line, "\#{").empty?

            interpol_starting_loc = []

          else

            interpol_starting_loc = find_all_matching_indices(modified_line, "\#{") + [-1]

          end

        end

        interpolated_strings.each do |interpol|

          string_split = line.split(interpol)

          if string_split[1].eql?("\"\n")

            replacement_string = "\" + " + "(#{interpol[2...-1]})"

            modified_file_contents[index] = modified_file_contents[index].sub(interpol+"\"", replacement_string)

          elsif string_split[1].eql?("\")\n")

            replacement_string = "\" + " + "(#{interpol[2...-1]})"

            modified_file_contents[index] = modified_file_contents[index].sub(interpol + "\"", replacement_string)

          else

            replacement_string = "\"" + " + " + "(#{interpol[2...-1]})" + " + \""

            modified_file_contents[index] = modified_file_contents[index].sub(interpol, replacement_string)

          end

        end

      end

    end

    return modified_file_contents

  end

  def replace_singleline_comments(input_file_contents)

    def replace_strings(input_string)

      string_counter = 0

      if input_string.count("\"") % 2 == 0

        while input_string.include?("\"")

        string_extract = input_string[input_string.index("\"")..input_string.index("\"",input_string.index("\"")+1)]

        input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

        string_counter += 1

        end

      end

      if input_string.count("'") % 2 == 0

        while input_string.include?("'")

          string_extract = input_string[input_string.index("'")..input_string.index("'",input_string.index("'")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

      end

      return input_string

    end

    single_line_comments = []

    singleline_comment_counter = 1

    modified_file_contents = input_file_contents.clone

    for x in 0...input_file_contents.length

      current_row = replace_strings(input_file_contents[x])

      if current_row.include?("#")

        current_row = modified_file_contents[x]

        comment_start = current_row.index("#")

        if current_row[comment_start+1] != "{"

          comment = current_row[comment_start..-1]

          single_line_comments << comment

          current_row = current_row.gsub(comment, "--single_line_comment[#{singleline_comment_counter}]\n\n")

          singleline_comment_counter += 1

        end

      else

        current_row = modified_file_contents[x]

      end

      modified_file_contents[x] = current_row

    end

    return modified_file_contents, single_line_comments

  end

  def replace_named_functions(nila_file_contents, temporary_nila_file)

    def extract_array(input_array, start_index, end_index)

      return input_array[start_index..end_index]

    end

    end_locations = []

    key_word_locations = []

    start_blocks = []

    end_blocks = []

    nila_regexp = /(def )/

    named_code_blocks = []

    for x in 0...nila_file_contents.length

      current_row = nila_file_contents[x]

      if current_row.index(nila_regexp) != nil

        key_word_locations << x

      elsif current_row.lstrip.eql?("end\n") || current_row.strip.eql?("end")

        end_locations << x


      end


    end

    unless key_word_locations.empty?

      modified_file_contents = nila_file_contents.dup

      for y in 0...end_locations.length

        current_location = end_locations[y]

        current_string = modified_file_contents[current_location]

        finder_location = current_location

        begin

          while current_string.index(nila_regexp) == nil

            finder_location -= 1

            current_string = modified_file_contents[finder_location]

          end

          code_block_begin = finder_location

          code_block_end = current_location

          start_blocks << code_block_begin

          end_blocks << code_block_end

          code_block_begin_string_split = modified_file_contents[code_block_begin].split(" ")

          code_block_begin_string_split[0] = code_block_begin_string_split[0].reverse

          code_block_begin_string = code_block_begin_string_split.join(" ")

          modified_file_contents[code_block_begin] = code_block_begin_string

        #rescue NoMethodError
        #
        #  puts "Function compilation failed!"

        end

      end

      final_modified_file_contents = nila_file_contents.dup

      joined_file_contents = final_modified_file_contents.join

      while start_blocks.length != 0

        top_most_level = start_blocks.min

        top_most_level_index = start_blocks.index(top_most_level)

        matching_level = end_blocks[top_most_level_index]

        named_code_blocks << extract_array(final_modified_file_contents, top_most_level, matching_level)

        start_blocks.delete_at(top_most_level_index)

        end_blocks.delete(matching_level)

      end

      codeblock_counter = 1

      named_functions = named_code_blocks.dup

      nested_functions = []

      named_code_blocks.each do |codeblock|

        if joined_file_contents.include?(codeblock.join)

          joined_file_contents = joined_file_contents.sub(codeblock.join, "--named_function[#{codeblock_counter}]\n")

          codeblock_counter += 1

          nested_functions = nested_functions + [[]]

        else

          nested_functions[codeblock_counter-2] << codeblock

          named_functions.delete(codeblock)

        end

      end

    else

      joined_file_contents = nila_file_contents.join

      named_functions = []

      nested_functions = []

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(joined_file_contents)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    return line_by_line_contents, named_functions, nested_functions


  end

  def compile_parallel_assignment(input_file_contents, temporary_nila_file)

    def arrayify_right_side(input_string)

      def replace_strings(input_string)

        string_counter = 0

        while input_string.include?("\"")

          string_extract = input_string[input_string.index("\"")..input_string.index("\"",input_string.index("\"")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

        while input_string.include?("'")

          string_extract = input_string[input_string.index("'")..input_string.index("'",input_string.index("'")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

        return input_string

      end

      modified_input_string = input_string.dup

      input_string = replace_strings(input_string)

      javascript_regexp = /(if |while |for |function |function\()/

      if input_string.include?("=") and input_string.index(javascript_regexp) == nil and input_string.strip[0..3] != "_ref" and !input_string.split("=")[1].include?("[")

        right_side = input_string.split("=")[1]

        if right_side.include?(",")

          splits = right_side.split(",")

          replacement_string = []

          splits.each do |str|

            unless str.include?(")") and !str.include?("(")

              replacement_string << str

            else

              replacement_string[-1] = replacement_string[-1]+ "," +str

            end

          end

          replacement_string = " [#{replacement_string.join(",").strip}]\n"

          modified_input_string = modified_input_string.sub(right_side,replacement_string)

        end

      end

      return modified_input_string

    end

    input_file_contents = input_file_contents.collect {|element| arrayify_right_side(element)}

    possible_variable_lines = input_file_contents.clone.reject { |element| !element.include? "=" }

    possible_parallel_assignment = possible_variable_lines.reject { |element| !element.split("=")[0].include? "," }

    parallel_assignment_index = []

    possible_parallel_assignment.each do |statement|

      location_array = input_file_contents.each_index.select { |index| input_file_contents[index] == statement }

      parallel_assignment_index << location_array[0]

    end

    modified_file_contents = input_file_contents.dup

    parallel_assignment_counter = 1

    possible_parallel_assignment.each_with_index do |line, index|

      line_split = line.split(" = ")

      right_side_variables = line_split[0].split(",")

      replacement_string = "_ref#{parallel_assignment_counter} = #{line_split[1]}\n\n"

      variable_string = ""

      right_side_variables.each_with_index do |variable, var_index|

        variable_string = variable_string + variable.rstrip + " = _ref#{parallel_assignment_counter}[#{var_index}]\n\n"

      end

      replacement_string = replacement_string + variable_string

      modified_file_contents[parallel_assignment_index[index]] = replacement_string

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(modified_file_contents.join)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    return line_by_line_contents

  end

  def compile_default_values(input_file_contents, temporary_nila_file)

    #This method compiles default values present in functions. An example is provided below

    # def fill(container = "cup",liquid = "coffee")
    #   puts "Filling the #{container} with #{liquid}"
    # end

    def errorFree(function_params)

      # This method checks for use cases in complex arguments where a default argument is used
      # after an optional argument. This will result in erroneous output. So this method will
      # stop it from happening.

      # Example:
      # def method_name(a,b,*c,d = 1,c,e)

      optional_param = function_params.reject {|element| !replace_strings(element).include?("*")}[0]

      unless optional_param.nil?

        after_splat = function_params[function_params.index(optional_param)+1..-1]

        if after_splat.reject {|element| !element.include?("=")}.empty?

          true

        else

          ParseError.new("You cannot have default argument after an optional argument! Change the following usage!\n#{function_params.join(",")}")

        end

      else

        true

      end

    end

    def parse_default_values(input_function_definition)

      split1, split2 = input_function_definition.split("(")

      split2, split3 = split2.split(")")

      function_parameters = split2.split(",")

      if errorFree(function_parameters)

        default_value_parameters = function_parameters.reject { |element| !element.include? "=" }

        replacement_parameters = []

        replacement_string = ""

        default_value_parameters.each do |paramvalue|

          param, value = paramvalue.split("=")

          replacement_parameters << param.lstrip.rstrip

          replacement_string = replacement_string + "\n" + "if (#{param.lstrip.rstrip} equequ null) {\n  #{paramvalue.lstrip.rstrip}\n}\n" +"\n"

        end

        return replacement_string, default_value_parameters, replacement_parameters

      end

    end

    reject_regexp = /(function |Euuf |if |else|elsuf|switch |case|while |whaaleskey |for )/

    input_file_contents = input_file_contents.collect { |element| element.gsub("==", "equalequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("!=", "notequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("+=", "plusequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("-=", "minusequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("*=", "multiequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("/=", "divequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("%=", "modequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("=~", "matchequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub(">=", "greatequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("<=", "lessyequal") }

    possible_default_values = input_file_contents.dup.reject { |element| (!element.include?("def")) }

    possible_default_values = possible_default_values.reject { |element| !element.include?("=") }

    possible_default_values = possible_default_values.reject {|element| !element.index(reject_regexp) == nil}

    if !possible_default_values.empty?

      possible_default_values.each do |line|

        current_line_index = input_file_contents.each_index.select { |index| input_file_contents[index] == line }.flatten[0]

        replacement_string, value_parameters, replacement_parameters = parse_default_values(line)

        modified_line = line.dup

        value_parameters.each_with_index do |val, index|

          modified_line = modified_line.sub(val, replacement_parameters[index])

        end

        input_file_contents[current_line_index] = modified_line

        input_file_contents.insert(current_line_index+1,replacement_string)

      end

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(input_file_contents.join)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("plusequal", "+=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("minusequal", "-=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("multiequal", "*=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("divequal", "/=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("modequal", "%=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("equalequal", "==") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("notequal", "!=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("matchequal", "=~") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("greatequal", ">=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("lessyequal", "<=") }

    return line_by_line_contents

  end

  def get_variables(input_file_contents, temporary_nila_file, *loop_variables)

    def replace_strings(input_string)

      string_counter = 0

      while input_string.include?("\"")

        string_extract = input_string[input_string.index("\"")..input_string.index("\"",input_string.index("\"")+1)]

        input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

        string_counter += 1

      end

      while input_string.include?("'")

        string_extract = input_string[input_string.index("'")..input_string.index("'",input_string.index("'")+1)]

        input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

        string_counter += 1

      end

      return input_string

    end

    variables = []

    input_file_contents = input_file_contents.collect { |element| element.gsub("==", "equalequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("!=", "notequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("+=", "plusequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("-=", "minusequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("*=", "multiequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("/=", "divequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("%=", "modequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("=~", "matchequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub(">=", "greatequal") }

    input_file_contents = input_file_contents.collect { |element| element.gsub("<=", "lessyequal") }

    modified_file_contents = input_file_contents.clone

    input_file_contents = input_file_contents.collect {|element| replace_strings(element)}

    javascript_regexp = /(if |while |for )/

    for x in 0...input_file_contents.length

      current_row = input_file_contents[x]

      if current_row.include?("=") and current_row.index(javascript_regexp) == nil

        current_row = current_row.rstrip + "\n"

        current_row_split = current_row.split("=")

        for y in 0...current_row_split.length

          current_row_split[y] = current_row_split[y].strip


        end

        if current_row_split[0].include?("[") or current_row_split[0].include?("(")

          current_row_split[0] = current_row_split[0][0...current_row_split[0].index("[")]

        end

        current_row_split[0] = current_row_split[0].split(".",2)[0].strip if current_row_split[0].include?(".")

        variables << current_row_split[0]


      end

      input_file_contents[x] = current_row

    end

    file_contents_as_string = modified_file_contents.join

    file_id = open(temporary_nila_file, 'w')

    file_id.write(file_contents_as_string)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    for_loop_variables = []

    for_loop_statements = line_by_line_contents.reject {|line| !line.include?("for")}
      
    for_loop_statements = for_loop_statements.reject {|line| line.include?("forEach")}

    for_loop_statements.each do |statement|

      varis = statement.split("for (")[1].split(";",2)[0].split(",")

      for_loop_variables << varis.collect {|vari| vari.strip.split("=")[0].strip}

      for_loop_variables = for_loop_variables.flatten

    end

    variables += loop_variables

    variables += for_loop_variables

    variables = variables.flatten

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("plusequal", "+=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("minusequal", "-=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("multiequal", "*=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("divequal", "/=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("modequal", "%=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("equalequal", "==") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("notequal", "!=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("matchequal", "=~") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("greatequal", ">=") }

    line_by_line_contents = line_by_line_contents.collect { |element| element.gsub("lessyequal", "<=") }

    return variables.uniq, line_by_line_contents

  end

  def remove_question_marks(input_file_contents, variable_list, temporary_nila_file)

    #A method to remove question marks from global variable names. Local variables are dealt
    #with in their appropriate scope.

    #Params:
    #input_file_contents => An array containing the contents of the input nila file
    #variable_list => An array containing all the global variables declared in the file
    #temporary_nila_file => A file object used to write temporary contents

    #Example:

    #Nila
    #isprime? = false

    #Javascript Output
    #var isprime;
    #isprime = false;

    #Returns a modified input_file_contents with all the question marks removed

    joined_file_contents = input_file_contents.join

    variable_list.each do |var|

      if var.include? "?"

        joined_file_contents = joined_file_contents.gsub(var, var[0...-1])

      end

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(joined_file_contents)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    return line_by_line_contents

  end

  def compile_arrays(input_file_contents, named_functions, temporary_nila_file)

    def compile_w_arrays(input_file_contents)

      def extract(input_string, pattern_start, pattern_end)

        def find_all_matching_indices(input_string, pattern)

          locations = []

          index = input_string.index(pattern)

          while index != nil

            locations << index

            index = input_string.index(pattern, index+1)


          end

          return locations


        end

        all_start_locations = find_all_matching_indices(input_string, pattern_start)

        all_end_locations = find_all_matching_indices(input_string, pattern_end)

        pattern = []

        all_start_locations.each_with_index do |location, index|

          pattern << input_string[location..all_end_locations[index]]

        end

        return pattern

      end

      def compile_w_syntax(input_string)

        modified_input_string = input_string[3...-1]

        string_split = modified_input_string.split(" ")

        return string_split.to_s

      end

      modified_file_contents = input_file_contents.dup

      input_file_contents.each_with_index do |line, index|

        if line.include?("%w{")

          string_arrays = extract(line, "%w{", "}")

          string_arrays.each do |array|

            modified_file_contents[index] = modified_file_contents[index].sub(array, compile_w_syntax(array))

          end

        end

      end

      return modified_file_contents

    end

    def compile_array_indexing(input_file_contents)

      possible_indexing_operation = input_file_contents.dup.reject { |element| !element.include? "[" and !element.include? "]" }

      possible_range_indexing = possible_indexing_operation.reject { |element| !element.include? ".." }

      triple_range_indexing = possible_range_indexing.reject { |element| !element.include? "..." }

      triple_range_indexes = []

      triple_range_indexing.each do |line|

        triple_range_indexes << input_file_contents.dup.each_index.select { |index| input_file_contents[index] == line }

      end

      triple_range_indexes = triple_range_indexes.flatten

      triple_range_indexing.each_with_index do |line, index|

        split1, split2 = line.split("[")

        range_index, split3 = split2.split("]")

        index_start, index_end = range_index.split "..."

        replacement_string = nil

        if index_end.strip == "last"

          replacement_string = split1 + ".slice(#{index_start},#{split}.length)\n"

        else

          replacement_string = split1 + ".slice(#{index_start},#{index_end})\n"

        end

        possible_range_indexing.delete(input_file_contents[triple_range_indexes[index]])

        possible_indexing_operation.delete(input_file_contents[triple_range_indexes[index]])

        input_file_contents[triple_range_indexes[index]] = replacement_string

      end

      double_range_indexing = possible_range_indexing.reject { |element| !element.include?("..") }

      double_range_indexes = []

      double_range_indexing.each do |line|

        double_range_indexes << input_file_contents.dup.each_index.select { |index| input_file_contents[index] == line }

      end

      double_range_indexes = double_range_indexes.flatten
      
      double_range_indexing.each_with_index do |line, index|

        split1, split2 = line.split("[")

        range_index, split3 = split2.split("]")

        index_start, index_end = range_index.split ".."

        index_start = "" if index_start.nil?

        index_end = "" if index_end.nil?
          
        split3 = "" if split3.nil?

        replacement_string = nil

        if index_end.strip == "last"

          replacement_string = split1 + ".slice(#{index_start})" + split3.strip + "\n\n"

        elsif index_end.strip == "" and index_start.strip == ""

          replacement_string = split1 + ".slice(0)\n"

        else

          replacement_string = split1 + ".slice(#{index_start},#{index_end}+1)\n"

        end

        possible_range_indexing.delete(input_file_contents[double_range_indexes[index]])

        possible_indexing_operation.delete(input_file_contents[double_range_indexes[index]])

        input_file_contents[double_range_indexes[index]] = replacement_string

      end

      duplicating_operations = input_file_contents.dup.reject { |element| !element.include?(".dup") }

      duplicating_operation_indexes = []

      duplicating_operations.each do |line|

        duplicating_operation_indexes << input_file_contents.dup.each_index.select { |index| input_file_contents[index] == line }

      end

      duplicating_operation_indexes = duplicating_operation_indexes.flatten

      duplicating_operation_indexes.each do |index|

        input_file_contents[index] = input_file_contents[index].sub(".dup", ".slice(0)")

      end

      return input_file_contents

    end

    def compile_multiline(input_file_contents, temporary_nila_file)

      possible_arrays = input_file_contents.reject { |element| !element.include?("[") }

      possible_multiline_arrays = possible_arrays.reject { |element| element.include?("]") }

      multiline_arrays = []

      possible_multiline_arrays.each do |starting_line|

        index = input_file_contents.index(starting_line)

        line = starting_line

        until line.include?("]")

          index += 1

          line = input_file_contents[index]

        end

        multiline_arrays << input_file_contents[input_file_contents.index(starting_line)..index]

      end

      joined_file_contents = input_file_contents.join

      multiline_arrays.each do |array|

        modified_array = array.join

        array_extract = modified_array[modified_array.index("[")..modified_array.index("]")]

        array_contents = array_extract.split("[")[1].split("]")[0].lstrip.rstrip.split(",").collect { |element| element.lstrip.rstrip }

        array_contents = "[" + array_contents.join(",") + "]"

        joined_file_contents = joined_file_contents.sub(array_extract, array_contents)

      end

      file_id = open(temporary_nila_file, 'w')

      file_id.write(joined_file_contents)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents

    end

    def compile_array_operators(input_file_contents)

      possible_operator_usage = input_file_contents.reject { |element| !element.include?("<<") }

      possible_operator_usage.each do |usage|

        left, right = usage.split("<<")

        input_file_contents[input_file_contents.index(usage)] = left.rstrip + ".push(#{right.strip})\n\n"

      end

      return input_file_contents

    end

    input_file_contents = compile_w_arrays(input_file_contents)

    input_file_contents = compile_array_indexing(input_file_contents)

    input_file_contents = compile_multiline(input_file_contents, temporary_nila_file)

    input_file_contents = compile_array_operators(input_file_contents)

    named_functions = named_functions.collect {|func| compile_w_arrays(func)}

    named_functions = named_functions.collect { |func| compile_array_indexing(func)}

    named_functions = named_functions.collect {|func| compile_multiline(func, temporary_nila_file)}

    named_functions = named_functions.collect {|func| compile_array_operators(func)}

    return input_file_contents, named_functions


  end

  def compile_hashes(input_file_contents,temporary_nila_file)

    def compile_multiline_hashes(input_file_contents,temporary_nila_file)

      def replace_strings(input_string)

        string_counter = 0

        while input_string.include?("\"")

          string_extract = input_string[input_string.index("\"")..input_string.index("\"",input_string.index("\"")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

        while input_string.include?("'")

          string_extract = input_string[input_string.index("'")..input_string.index("'",input_string.index("'")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

        return input_string

      end

      javascript_regexp = /(if |while |for |function |function\()/

      modified_file_contents = input_file_contents.clone

      input_file_contents = input_file_contents.collect {|line| replace_strings(line)}

      possible_hashes = input_file_contents.reject { |element| !element.include?("{") }

      possible_multiline_hashes = possible_hashes.reject { |element| element.include?("}") }

      possible_multiline_hashes = possible_multiline_hashes.reject {|element| element.index(javascript_regexp) != nil}

      multiline_hashes = []

      possible_multiline_hashes.each do |starting_line|

        index = input_file_contents.index(starting_line)

        line = modified_file_contents[index]

        until line.include?("}\n")

          index += 1

          line = modified_file_contents[index]

        end

        multiline_hashes << modified_file_contents[input_file_contents.index(starting_line)..index]

      end

      joined_file_contents = modified_file_contents.join

      multiline_hashes.each do |hash|

        modified_hash = hash.join

        hash_extract = modified_hash[modified_hash.index("{")..modified_hash.index("}")]

        hash_contents = hash_extract.split("{")[1].split("}")[0].lstrip.rstrip.split(",").collect { |element| element.lstrip.rstrip }

        hash_contents = "{" + hash_contents.join(",") + "}"

        joined_file_contents = joined_file_contents.sub(hash_extract, hash_contents)

      end

      file_id = open(temporary_nila_file, 'w')

      file_id.write(joined_file_contents)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents

    end

    def compile_inline_hashes(input_file_contents)

      def replace_strings(input_string)

        string_counter = 0

        while input_string.include?("\"")

          string_extract = input_string[input_string.index("\"")..input_string.index("\"",input_string.index("\"")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

        while input_string.include?("'")

          string_extract = input_string[input_string.index("'")..input_string.index("'",input_string.index("'")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

        return input_string

      end

      javascript_regexp = /(if |while |for |function |function\(|%[qQw]*\{)/

      modified_file_contents = input_file_contents.clone.collect {|element| replace_strings(element)}

      possible_inline_hashes = modified_file_contents.reject {|element| element.count("{") != 1}

      possible_inline_hashes = possible_inline_hashes.reject {|element| element.count("}") != 1}

      possible_inline_hashes = possible_inline_hashes.reject {|element| element.index(javascript_regexp) != nil}

      possible_inline_hashes = possible_inline_hashes.reject {|element| element.include?("{}")}

      possible_inline_hashes.each do |hash|

        hash = input_file_contents[modified_file_contents.index(hash)]

        hash_extract = hash[hash.index("{")..hash.index("}")]

        contents = hash_extract[1...-1].split(",")

        hash_contents = []

        contents.each do |items|

          items = items.lstrip.sub(":","") if items.lstrip[0] == ":"

          key, value = items.split("=>").collect {|element| element.lstrip.rstrip} if items.include?("=>")

          key, value = items.split(":").collect {|element| element.lstrip.rstrip} if items.include?(":")

          key = key.gsub("'","").gsub("\"","")

          hash_contents << "  #{key}: #{value},"

        end

        replacement_string = "{\n" + hash_contents.join("\n") + "\n};\n"

        input_file_contents[input_file_contents.index(hash)] = input_file_contents[input_file_contents.index(hash)].sub(hash_extract,replacement_string)

      end

      return input_file_contents

    end

    file_contents = compile_multiline_hashes(input_file_contents,temporary_nila_file)

    file_contents = compile_inline_hashes(file_contents)

    return file_contents

  end

  def compile_strings(input_file_contents)

    def compile_small_q_syntax(input_file_contents)

      possible_syntax_usage = input_file_contents.reject { |element| !element.include?("%q") }

      possible_syntax_usage.each do |line|

        modified_line = line.dup

        line_split = line.split("+").collect { |element| element.lstrip.rstrip }

        line_split.each do |str|

          delimiter = str[str.index("%q")+2]

          string_extract = str[str.index("%q")..-1]

          delimiter = "}" if delimiter.eql?("{")

          delimiter = ")" if delimiter.eql?("(")

          delimiter = ">" if delimiter.eql?("<")

          if string_extract[-1].eql?(delimiter)

            input_file_contents[input_file_contents.index(modified_line)] = input_file_contents[input_file_contents.index(modified_line)].sub(string_extract, "'#{string_extract[3...-1]}'")

            modified_line = modified_line.sub(string_extract, "'#{string_extract[3...-1]}'")

          elsif delimiter.eql?(" ")

            input_file_contents[input_file_contents.index(modified_line)] = input_file_contents[input_file_contents.index(modified_line)].sub(string_extract, "'#{string_extract[3..-1]}'")

            modified_line = modified_line.sub(string_extract, "'#{string_extract[3..-1]}'")

          end

        end

      end

      return input_file_contents

    end

    def compile_big_q_syntax(input_file_contents)

      possible_syntax_usage = input_file_contents.reject { |element| !element.include?("%Q") }

      possible_syntax_usage.each do |line|

        modified_line = line.dup

        line_split = line.split("+").collect { |element| element.lstrip.rstrip }

        line_split.each do |str|

          delimiter = str[str.index("%Q")+2]

          string_extract = str[str.index("%Q")..-1]

          delimiter = "}" if delimiter.eql?("{")

          delimiter = ")" if delimiter.eql?("(")

          delimiter = ">" if delimiter.eql?("<")

          if string_extract[-1].eql?(delimiter)

            input_file_contents[input_file_contents.index(modified_line)] = input_file_contents[input_file_contents.index(modified_line)].sub(string_extract, "\"#{string_extract[3...-1]}\"")

            modified_line = modified_line.sub(string_extract, "\"#{string_extract[3...-1]}\"")

          elsif delimiter.eql?(" ")

            input_file_contents[input_file_contents.index(modified_line)] = input_file_contents[input_file_contents.index(modified_line)].sub(string_extract, "\"#{string_extract[3..-1]}\"")

            modified_line = modified_line.sub(string_extract, "\"#{string_extract[3..-1]}\"")

          end

        end

      end

      return input_file_contents

    end

    def compile_percentage_syntax(input_file_contents)

      possible_syntax_usage = input_file_contents.reject { |element| !element.include?("%") }

      possible_syntax_usage = possible_syntax_usage.reject { |element| element.index(/(\%(\W|\s)\w{1,})/).nil? }

      possible_syntax_usage.each do |line|

        modified_line = line.dup

        line_split = line.split("+").collect { |element| element.lstrip.rstrip }

        line_split.each do |str|

          delimiter = str[str.index("%")+1]

          string_extract = str[str.index("%")..-1]

          delimiter = "}" if delimiter.eql?("{")

          delimiter = ")" if delimiter.eql?("(")

          delimiter = ">" if delimiter.eql?("<")

          if string_extract[-1].eql?(delimiter)

            input_file_contents[input_file_contents.index(modified_line)] = input_file_contents[input_file_contents.index(modified_line)].sub(string_extract, "\"#{string_extract[2...-1]}\"")

            modified_line = modified_line.sub(string_extract, "\"#{string_extract[2...-1]}\"")

          elsif delimiter.eql?(" ")

            input_file_contents[input_file_contents.index(modified_line)] = input_file_contents[input_file_contents.index(modified_line)].sub(string_extract, "\"#{string_extract[2..-1]}\"")

            modified_line = modified_line.sub(string_extract, "\"#{string_extract[2..-1]}\"")

          end

        end

      end

      return input_file_contents

    end

    file_contents = compile_small_q_syntax(input_file_contents)

    file_contents = compile_big_q_syntax(file_contents)

    file_contents = compile_percentage_syntax(file_contents)

    return file_contents

  end

  def compile_integers(input_file_contents)

    modified_file_contents = input_file_contents.clone

    input_file_contents.each_with_index do |line,index|

      matches = line.scan(/(([0-9]+_)+([0-9]+|$))/)

      unless matches.empty?

        matches.each do |match_arr|

            modified_file_contents[index] = modified_file_contents[index].sub(match_arr[0],match_arr[0].gsub("_",""))

        end

      end

    end

    return modified_file_contents

  end

  def compile_named_functions(input_file_contents, named_code_blocks, nested_functions, temporary_nila_file)

    #This method compiles all the named Nila functions. Below is an example of what is meant
    #by named/explicit function

    #def square(input_number)
    #
    #   input_number*input_number
    #
    #end

    #The above function will compile to

    #square = function(input_number) {
    #
    #  return input_number*input_number;
    #
    #};

    def is_parameterless?(input_function_block)

      if input_function_block[0].include?("(")

        false

      else

        true

      end

    end

    def lexical_scoped_variables(input_function_block)

      #This method will pickup and declare all the variables inside a function block. In future, this method will be
      #merged with the get variables method

      def replace_strings(input_string)

        element = input_string.gsub("==", "equalequal")

        element = element.gsub("!=", "notequal")

        element = element.gsub("+=", "plusequal")

        element = element.gsub("-=", "minusequal")

        element = element.gsub("*=", "multiequal")

        element = element.gsub("/=", "divequal")

        element = element.gsub("%=", "modequal")

        element = element.gsub("=~", "matchequal")

        element = element.gsub(">=", "greatequal")

        input_string = element.gsub("<=", "lessyequal")

        string_counter = 0

        while input_string.include?("\"")

          string_extract = input_string[input_string.index("\"")..input_string.index("\"",input_string.index("\"")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

        while input_string.include?("'")

          string_extract = input_string[input_string.index("'")..input_string.index("'",input_string.index("'")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

        return input_string

      end

      input_function_block = input_function_block.collect {|element| replace_strings(element)}

      controlregexp = /(if |Euuf |for |while |def |function |function\()/

      variables = []

      function_name, parameters = input_function_block[0].split("(")

      parameters = parameters.split(")")[0].split(",")

      parameters = parameters.collect { |element| element.strip }

      input_function_block.each do |line|

        if line.include? "=" and line.index(controlregexp).nil?

          current_line_split = line.strip.split("=")

          variables << current_line_split[0].rstrip

        end

      end

      parameters.each do |param|

        if variables.include?(param)

          variables.delete(param)

        end

      end

      if variables.empty?

        return []

      else

        return variables.uniq.sort

      end

    end

    def remove_question_marks(input_file_contents, input_list, temporary_nila_file)

      joined_file_contents = input_file_contents.join

      input_list.each do |element|

        if element.include? "?"

          joined_file_contents = joined_file_contents.gsub(element, element[0...-1])

        end

      end

      file_id = open(temporary_nila_file, 'w')

      file_id.write(joined_file_contents)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents

    end

    def add_auto_return_statement(input_array)

      joined_array = input_array.join

      reversed_input_array = input_array.reverse

      if !joined_array.include?("return ")

        rejected_array = reversed_input_array.reject { |content| content.lstrip.eql?("") }

        rejected_array = rejected_array.reject {|content| content.strip.eql?("")}

        rejected_array = rejected_array[1..-1]

        if !rejected_array[0].strip.eql?("}")

          if !rejected_array[0].strip.eql?("end") and !rejected_array[0].strip.include?("--single_line_comment")

            last_statement = rejected_array[0]

            replacement_string = "return #{last_statement.lstrip}"

            input_array[input_array.index(last_statement)] = replacement_string

          end

        end

      end

      return input_array

    end

    def compile_multiple_return(input_array)

      def find_all_matching_indices(input_string, pattern)

        locations = []

        index = input_string.index(pattern)

        while index != nil

          locations << index

          index = input_string.index(pattern, index+1)


        end

        return locations


      end

      modified_input_array = input_array.dup

      return_statements = input_array.dup.reject { |element| !element.include? "return" }

      multiple_return_statements = return_statements.dup.reject { |element| !element.include? "," }

      modified_multiple_return_statements = multiple_return_statements.dup

      return_statement_index = []

      multiple_return_statements.each do |statement|

        location_array = modified_input_array.each_index.select { |index| modified_input_array[index] == statement }

        return_statement_index << location_array[0]

      end

      multiple_return_statements.each_with_index do |return_statement, index|

        replacement_counter = 0

        if return_statement.include? "\""

          starting_quotes = find_all_matching_indices(return_statement, "\"")

          for x in 0...(starting_quotes.length)/2

            quotes = return_statement[starting_quotes[x]..starting_quotes[x+1]]

            replacement_counter += 1

            modified_multiple_return_statements[index] = modified_multiple_return_statements[index].sub(quotes, "repstring#{1}")

            modified_input_array[return_statement_index[index]] = modified_multiple_return_statements[index].sub(quotes, "repstring#{1}")

          end

        end

      end

      modified_multiple_return_statements = modified_multiple_return_statements.reject { |element| !element.include? "," }

      return_statement_index = []

      modified_multiple_return_statements.each do |statement|

        location_array = modified_input_array.each_index.select { |index| modified_input_array[index] == statement }

        return_statement_index << location_array[0]

      end

      modified_multiple_return_statements.each_with_index do |return_statement, index|

        method_call_counter = 0

        if return_statement.include? "("

          open_paran_location = find_all_matching_indices(return_statement, "(")

          open_paran_location.each do |paran_index|

            method_call = return_statement[paran_index..return_statement.index(")", paran_index+1)]

            method_call_counter += 1

            modified_multiple_return_statements[index] = modified_multiple_return_statements[index].sub(method_call, "methodcall#{method_call_counter}")

            modified_input_array[return_statement_index[index]] = modified_multiple_return_statements[index].sub(method_call, "methodcall#{method_call_counter}")

          end

        end

      end

      modified_multiple_return_statements = modified_multiple_return_statements.reject { |element| !element.include?(",") }

      return_statement_index = []

      modified_multiple_return_statements.each do |statement|

        location_array = modified_input_array.each_index.select { |index| modified_input_array[index] == statement }

        return_statement_index << location_array[0]

      end

      return_statement_index.each do |index|

        original_statement = input_array[index]

        statement_split = original_statement.split("return ")

        replacement_split = "return [" + statement_split[1].rstrip + "]\n\n"

        input_array[index] = replacement_split

      end

      return input_array

    end

    def coffee_type_function(input_array)

      function_name = input_array[0].split("function ")[1].split("(")[0].lstrip

      input_array[0] = "#{function_name} = function(" + input_array[0].split("function ")[1].split("(")[1].lstrip

      return input_array

    end

    def compile_function(input_array, temporary_nila_file)

      modified_input_array = input_array.dup

      if is_parameterless?(modified_input_array)

        if modified_input_array[0].include?("--single")

          modified_input_array[0] = input_array[0].sub "def", "function"

          interim_string = modified_input_array[0].split("--single")

          modified_input_array[0] = interim_string[0].rstrip + "() {\n--single" + interim_string[1]


        elsif modified_input_array[0].include?("--multi")

          modified_input_array[0] = input_array[0].sub "def", "function"

          interim_string = modified_input_array[0].split("--multi")

          modified_input_array[0] = interim_string[0].rstrip + "() {\n--multi" + interim_string[1]

        else

          modified_input_array[0] = input_array[0].sub "def", "function"

          modified_input_array[0] = modified_input_array[0].rstrip + "() {\n"

        end

      else

        if modified_input_array[0].include?("--single")

          modified_input_array[0] = input_array[0].sub "def", "function"

          interim_string = modified_input_array[0].split("--single")

          modified_input_array[0] = interim_string[0].rstrip + " {\n--single" + interim_string[1]


        elsif modified_input_array[0].include?("--multi")

          modified_input_array[0] = input_array[0].sub "def", "function"

          interim_string = modified_input_array[0].split("--multi")

          modified_input_array[0] = interim_string[0].rstrip + " {\n--multi" + interim_string[1]

        else

          modified_input_array[0] = input_array[0].sub "def", "function"

          modified_input_array[0] = modified_input_array[0].rstrip + " {\n"

        end

      end

      modified_input_array[-1] = input_array[-1].sub "end", "};\n"

      modified_input_array = compile_parallel_assignment(modified_input_array, temporary_nila_file)

      modified_input_array = compile_multiple_ruby_func_calls(modified_input_array)

      modified_input_array = add_auto_return_statement(modified_input_array)

      modified_input_array = compile_multiple_return(modified_input_array)

      modified_input_array = coffee_type_function(modified_input_array)

      modified_input_array = compile_splats(modified_input_array)

      variables = lexical_scoped_variables(modified_input_array)

      if !variables.empty?

        variable_string = "\nvar " + variables.join(", ") + "\n"

        modified_input_array.insert(1, variable_string)

      end

      modified_input_array = remove_question_marks(modified_input_array, variables, temporary_nila_file)

      return modified_input_array

    end

    def extract_function_name(input_code_block)

      first_line = input_code_block[0]

      first_line_split = first_line.split(" ")

      if first_line_split[1].include?("(")

        function_name, parameters = first_line_split[1].split("(")

      else

        function_name = first_line_split[1]

      end

      return function_name

    end

    def compile_splats(input_function_block)

      def strToArray(input_string)

        file_id = File.new('hello.nila','w')

        file_id.write(input_string)

        file_id.close()

        line_by_line_contents = read_file_line_by_line('hello.nila')

        File.delete(file_id)

        return line_by_line_contents

      end

      def errorFree(function_params,optional_param)

        # This method checks for use cases in complex arguments where a default argument is used
        # after an optional argument. This will result in erroneous output. So this method will
        # stop it from happening.

        # Example:
        # def method_name(a,b,*c,d = 1,c,e)

        after_splat = function_params[function_params.index(optional_param)+1..-1]

        if after_splat.reject {|element| !element.include?("=")}.empty?

          true

        else

          raise "You cannot have a default argument after an optional argument!"

          false

        end

      end

      function_params = input_function_block[0].split("function(")[1].split(")")[0].split(",")

      unless function_params.reject{|element| !replace_strings(element).include?("*")}.empty?

        mod_function_params = function_params.reject {|element| replace_strings(element).include?("*")}

        opt_index = 0

        # If there are multiple optional params declared by mistake, only the first optional param is used.

        optional_param = function_params.reject {|element| !replace_strings(element).include?("*")}[0]

        if function_params.index(optional_param).eql?(function_params.length-1)

          mod_function_params.each_with_index do |param,index|

            input_function_block.insert(index+1,"#{param} = arguments[#{index}]\n\n")

            opt_index = index + 1

          end

          replacement_string = "#{optional_param.gsub("*","")} = []\n\n"

          replacement_string += "for (var i=#{opt_index};i<arguments.length;i++) {\n #{optional_param.gsub("*","")}.push(arguments[i]); \n}\n\n"

          input_function_block.insert(opt_index+1,replacement_string)

          input_function_block[0] = input_function_block[0].sub(function_params.join(","),"")

        else

          before_splat = function_params[0...function_params.index(optional_param)]

          after_splat = function_params[function_params.index(optional_param)+1..-1]

          cont_index = 0

          if errorFree(function_params,optional_param)

            before_splat.each_with_index do |param,index|

              input_function_block.insert(index+1,"#{param} = arguments[#{index}]\n\n")

              cont_index = index + 1

            end

            after_splat.each_with_index do |param,index|

              input_function_block.insert(cont_index+1,"#{param} = arguments[arguments.length-#{after_splat.length - index}]\n\n")

              cont_index = cont_index + 1

            end

            replacement_string = "#{optional_param.gsub("*","")} = []\n\n"

            replacement_string += "for (var i=#{function_params.index(optional_param)};i < arguments.length-#{after_splat.length};i++) {\n #{optional_param.gsub("*","")}.push(arguments[i]); \n}\n\n"

            input_function_block.insert(cont_index+1,replacement_string)

            input_function_block[0] = input_function_block[0].sub(function_params.join(","),"")

          end

        end

      end

      return strToArray(input_function_block.join)

    end

    def compile_multiple_ruby_func_calls(input_file_contents)

      def strToArray(input_string)

        file_id = File.new('hello.nila','w')

        file_id.write(input_string)

        file_id.close()

        line_by_line_contents = read_file_line_by_line('hello.nila')

        File.delete(file_id)

        return line_by_line_contents

      end

      def replace_strings(input_string)

        string_counter = 0

        if input_string.count("\"") % 2 == 0

          while input_string.include?("\"")

            string_extract = input_string[input_string.index("\"")..input_string.index("\"",input_string.index("\"")+1)]

            input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

            string_counter += 1

          end

        end

        if input_string.count("'") % 2 == 0

          while input_string.include?("'")

            string_extract = input_string[input_string.index("'")..input_string.index("'",input_string.index("'")+1)]

            input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

            string_counter += 1

          end

        end

        input_string = input_string.gsub(/\((\w{0,},)*\w{0,}\)/,"--$k$")

        return input_string

      end

      function_calls = []

      replacement_calls = []

      function_map = %w{puts p print}

      javascript_regexp = /(if |for |while |\(function\(|= function\(|((=|:)\s+\{))/

      stringified_input = input_file_contents.collect {|element| replace_strings(element)}

      function_map.each do |func|

        func_calls = input_file_contents.reject {|line| !(line.include?(func+"(") or line.include?(func+" ") and line.index(javascript_regexp) == nil)}

        modified_func_calls = func_calls.collect {|element| replace_strings(element)}

        modified_func_calls = modified_func_calls.reject {|element| !element.include?(",")}

        call_collector = []

        modified_func_calls.each_with_index do |ele|

          call_collector << input_file_contents[stringified_input.index(ele)]

        end

        function_calls << modified_func_calls

        rep_calls = []

        call_collector.each do |fcall|

          multiple_call = fcall.split(func)[1].split(",")

          multiple_call = multiple_call.collect {|element| "\n#{func} " + element.strip + "\n\n"}

          rep_calls << multiple_call.join

        end

        replacement_calls << rep_calls

      end

      replacement_calls = replacement_calls.flatten

      function_calls = function_calls.flatten

      function_calls.each_with_index do |fcall,index|

        input_file_contents[stringified_input.index(fcall)] = replacement_calls[index]

      end

      return strToArray(input_file_contents.join)

    end

    joined_file_contents = input_file_contents.join

    unless named_code_blocks.empty?

      codeblock_counter = 1

      function_names = []

      named_code_blocks.each do |codeblock|

        function_names[codeblock_counter-1] = []

        joined_file_contents = joined_file_contents.sub("--named_function[#{codeblock_counter}]\n", compile_function(codeblock, temporary_nila_file).join)

        codeblock_counter += 1

        current_nested_functions = nested_functions[codeblock_counter-2]

        function_names[codeblock_counter-2] << extract_function_name(codeblock)

        current_nested_functions.each do |nested_function|

          function_names[codeblock_counter-2] << extract_function_name(nested_function)

          joined_file_contents = joined_file_contents.sub(nested_function.join, compile_function(nested_function, temporary_nila_file).join)

        end

      end

    else

      function_names = []

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(joined_file_contents)

    file_id.close()

    line_by_line_contents = compile_multiple_ruby_func_calls(read_file_line_by_line(temporary_nila_file))

    return line_by_line_contents, function_names

  end

  def compile_custom_function_map(input_file_contents)

    function_map_replacements = {

        "puts" => "console.log",

        "p" => "console.log",

        "print" => "process.stdout.write",

    }

    function_map = function_map_replacements.keys

    modified_file_contents = input_file_contents.dup

    javascript_regexp = /(if |for |while |\(function\(|= function\(|((=|:)\s+\{))/

    input_file_contents.each_with_index do |line, index|

      function_map.each do |function|

        if line.include?(function+"(") or line.include?(function+" ") and line.index(javascript_regexp) == nil

          testsplit =  line.split(function)

          testsplit = testsplit.collect {|element| element.strip}

          testsplit[0] = " " if testsplit[0].eql?("")

          if testsplit[0][-1].eql?(" ") or testsplit[0].eql?("return")

            modified_file_contents[index] = line.sub(function, function_map_replacements[function])

          end

        end

      end

    end

    return modified_file_contents, function_map_replacements.values

  end

  def compile_ruby_methods(input_file_contents)

    # These are some interesting methods that we really miss in Javascript.
    # So we have made these methods available

    method_map_replacement = {

        ".split" => ".split(\" \")",

        ".join" => ".join()",

        ".strip" => ".replace(/^\\s+|\\s+$/g,'')",

        ".lstrip" => ".replace(/^\\s+/g,\"\")",

        ".rstrip" => ".replace(/\\s+$/g,\"\")",

        ".to_s" => ".toString()",

        ".reverse" => ".reverse()",

        ".empty?" => ".length == 0",

        ".upcase" => ".toUpperCase()",

        ".downcase" => ".toLowerCase()",

    }

    method_map = method_map_replacement.keys

    method_map_regex = method_map.collect {|name| name.gsub(".","\\.")}

    method_map_regex = Regexp.new(method_map_regex.join("|"))

    modified_file_contents = input_file_contents.clone

    input_file_contents.each_with_index do |line, index|

      if line.match(method_map_regex)

        method_match = line.match(method_map_regex).to_a[0]

        unless line.include?(method_match + "(")

          line = line.sub(method_match,method_map_replacement[method_match])

        end

      end

      modified_file_contents[index] = line

    end

    return modified_file_contents

  end

  def compile_special_keywords(input_file_contents)

    # This method compiles some Ruby specific keywords to Javascript to make it easy to port
    # Ruby code into Javascript

    def replace_strings(input_string)

      string_counter = 0

      if input_string.count("\"") % 2 == 0

        while input_string.include?("\"")

          string_extract = input_string[input_string.index("\"")..input_string.index("\"",input_string.index("\"")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

      end

      if input_string.count("'") % 2 == 0

        while input_string.include?("'")

          string_extract = input_string[input_string.index("'")..input_string.index("'",input_string.index("'")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

      end

      return input_string

    end

    keyword_replacement_map = {

        "nil" => "null",

        "Array.new" => "new Array()"

    }

    special_keywords = keyword_replacement_map.keys

    keyword_map_regex = special_keywords.collect {|name| name.gsub(".","\\.")}

    keyword_map_regex = Regexp.new(keyword_map_regex.join("|"))

    modified_file_contents = input_file_contents.clone

    input_file_contents.each_with_index do |line, index|

      if replace_strings(line).match(keyword_map_regex)

        method_match = line.match(keyword_map_regex).to_a[0]

        if line.split(keyword_map_regex)[0].include?("=")

          line = line.sub(method_match,keyword_replacement_map[method_match])

        end

      end

      modified_file_contents[index] = line

    end

    return modified_file_contents

  end

  def compile_whitespace_delimited_functions(input_file_contents, function_names, temporary_nila_file)

    def extract(input_string, pattern_start, pattern_end)

      def find_all_matching_indices(input_string, pattern)

        locations = []

        index = input_string.index(pattern)

        while index != nil

          locations << index

          index = input_string.index(pattern, index+1)


        end

        return locations


      end

      all_start_locations = find_all_matching_indices(input_string, pattern_start)

      pattern = []

      all_start_locations.each do |location|

        extracted_string = input_string[location..-1]

        string_extract = extracted_string[0..extracted_string.index(pattern_end)]

        if !string_extract.include?(" = function(")

          pattern << string_extract

        end

      end

      return pattern

    end

    begin

      input_file_contents[-1] = input_file_contents[-1] + "\n" if !input_file_contents[-1].include?("\n")

      joined_file_contents = input_file_contents.join

      function_names.each do |list_of_functions|

        list_of_functions.each do |function|

          matching_strings = extract(joined_file_contents, function+" ", "\n")

          matching_strings.each do |string|

            modified_string = string.dup

            modified_string = modified_string.rstrip + modified_string.split(modified_string.rstrip)[1].gsub(" ", "")

            modified_string = modified_string.sub(function+" ", function+"(")

            modified_string = modified_string.split("#{function}(")[0] + "#{function}(" + modified_string.split("#{function}(")[1].lstrip

            modified_string = modified_string.sub("\n", ")\n")

            joined_file_contents = joined_file_contents.sub(string, modified_string)

          end

        end

      end

    rescue NoMethodError

      puts "Whitespace delimitation exited with errors!"

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(joined_file_contents)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    return line_by_line_contents

  end

  def compile_conditional_structures(input_file_contents, temporary_nila_file)

    def replace_unless_until(input_file_contents)

      modified_file_contents = input_file_contents.clone

      possible_unless_commands = input_file_contents.reject { |element| !element.include?("unless") }

      unless_commands = possible_unless_commands.reject { |element| !element.lstrip.split("unless")[0].empty? }

      unless_commands.each do |command|

        junk, condition = command.split("unless ")

        condition = condition.gsub(" and "," && ").gsub(" or "," || ").gsub(" not "," !")

        replacement_string = "if !(#{condition.lstrip.rstrip})\n"

        modified_file_contents[modified_file_contents.index(command)] = replacement_string

      end

      possible_until_commands = input_file_contents.reject { |element| !element.include?("until") }

      until_commands = possible_until_commands.reject { |element| !element.lstrip.split("until")[0].empty? }

      until_commands.each do |command|

        junk, condition = command.split("until ")

        condition = condition.gsub(" and "," && ").gsub(" or "," || ").gsub(" not "," !")

        replacement_string = "while !(#{condition.lstrip.rstrip})\n"

        modified_file_contents[modified_file_contents.index(command)] = replacement_string

      end

      return modified_file_contents

    end

    def compile_ternary_if(input_file_contents)

      possible_ternary_if = input_file_contents.reject{|element| !element.include?("if")}

      possible_ternary_if = possible_ternary_if.reject {|element| !element.include?("then")}

      possible_ternary_if.each do |statement|

        statement_extract = statement[statement.index("if")..statement.index("end")+2]

        condition = statement_extract.split("then")[0].split("if")[1].lstrip.rstrip

        true_condition = statement_extract.split("then")[1].split("else")[0].lstrip.rstrip

        false_condition = statement_extract.split("else")[1].split("end")[0].lstrip.rstrip

        replacement_string = "#{condition} ? #{true_condition} : #{false_condition}"

        input_file_contents[input_file_contents.index(statement)] = input_file_contents[input_file_contents.index(statement)].sub(statement_extract,replacement_string)

      end

      return input_file_contents

    end

    def compile_inline_conditionals(input_file_contents, temporary_nila_file)

      conditionals = [/( if )/, /( while )/, /( unless )/, /( until )/]

      plain_conditionals = [" if ", " while ", " unless ", " until "]

      joined_file_contents = input_file_contents.join

      output_statement = ""

      conditionals.each_with_index do |regex, index|

        matching_lines = input_file_contents.reject { |content| content.index(regex).nil? }

        matching_lines.each do |line|

          line_split = line.split(plain_conditionals[index])

          condition = line_split[1]

          condition = condition.gsub(" and "," && ").gsub(" or "," || ").gsub(" not "," !")

          if index == 0

            output_statement = "if (#{condition.lstrip.rstrip.gsub("?", "")}) {\n\n#{line_split[0]}\n}\n"

          elsif index == 1

            output_statement = "while (#{condition.lstrip.rstrip.gsub("?", "")}) {\n\n#{line_split[0]}\n}\n"

          elsif index == 2

            output_statement = "if (!(#{condition.lstrip.rstrip.gsub("?", "")})) {\n\n#{line_split[0]}\n}\n"

          elsif index == 3

            output_statement = "while (!(#{condition.lstrip.rstrip.gsub("?", "")})) {\n\n#{line_split[0]}\n}\n"

          end

          joined_file_contents = joined_file_contents.sub(line, output_statement)

        end

      end

      file_id = open(temporary_nila_file, 'w')

      file_id.write(joined_file_contents)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents

    end

    def compile_regular_if(input_file_contents, temporary_nila_file)

      def convert_string_to_array(input_string, temporary_nila_file)

        file_id = open(temporary_nila_file, 'w')

        file_id.write(input_string)

        file_id.close()

        line_by_line_contents = read_file_line_by_line(temporary_nila_file)

        return line_by_line_contents

      end

      def extract_if_blocks(if_statement_indexes, input_file_contents)

        possible_if_blocks = []

        if_block_counter = 0

        extracted_blocks = []

        controlregexp = /(if |while |def | do )/

        rejectionregexp = /( if | while )/

        for x in 0...if_statement_indexes.length-1

          possible_if_blocks << input_file_contents[if_statement_indexes[x]..if_statement_indexes[x+1]]

        end

        end_counter = 0

        end_index = []

        current_block = []

        possible_if_blocks.each_with_index do |block|

          unless current_block[-1] == block[0]

            current_block += block

          else

            current_block += block[1..-1]

          end


          current_block.each_with_index do |line, index|

            if line.strip.eql? "end"

              end_counter += 1

              end_index << index

            end

          end

          if end_counter > 0

            until end_index.empty?

              array_extract = current_block[0..end_index[0]].reverse

              index_counter = 0

              array_extract.each_with_index do |line|

                break if (line.lstrip.index(controlregexp) != nil and line.lstrip.index(rejectionregexp).nil?)

                index_counter += 1

              end

              block_extract = array_extract[0..index_counter].reverse

              extracted_blocks << block_extract

              block_start = current_block.index(block_extract[0])

              block_end = current_block.index(block_extract[-1])

              current_block[block_start..block_end] = "--ifblock#{if_block_counter}"

              if_block_counter += 1

              end_counter = 0

              end_index = []

              current_block.each_with_index do |line, index|

                if line.strip.eql? "end"

                  end_counter += 1

                  end_index << index

                end

              end

            end

          end

        end

        return current_block, extracted_blocks

      end

      def compile_if_syntax(input_block)

        strings = []

        string_counter = 0

        modified_input_block = input_block.dup

        input_block.each_with_index do |line, index|

          if line.include?("\"")

            opening_quotes = line.index("\"")

            string_extract = line[opening_quotes..line.index("\"", opening_quotes+1)]

            strings << string_extract

            modified_input_block[index] = modified_input_block[index].sub(string_extract, "--string{#{string_counter}}")

            string_counter += 1

          end

        end

        input_block = modified_input_block

        starting_line = input_block[0]

        starting_line = starting_line + "\n" if starting_line.lstrip == starting_line

        junk, condition = starting_line.split("if")

        condition = condition.gsub(" and "," && ").gsub(" or "," || ").gsub(" not "," !")

        input_block[0] = "Euuf (#{condition.lstrip.rstrip.gsub("?", "")}) {\n"

        input_block[-1] = input_block[-1].lstrip.sub("end", "}")

        elsif_statements = input_block.reject { |element| !element.include?("elsuf") }

        elsif_statements.each do |statement|

          junk, condition = statement.split("elsuf")

          condition = condition.gsub(" and "," && ").gsub(" or "," || ").gsub(" not "," !")

          input_block[input_block.index(statement)] = "} elsuf (#{condition.lstrip.rstrip.gsub("?", "")}) {\n"

        end

        else_statements = input_block.reject { |element| !element.include?("else") }

        else_statements.each do |statement|

          input_block[input_block.index(statement)] = "} else {\n"

        end

        modified_input_block = input_block.dup

        input_block.each_with_index do |line, index|

          if line.include?("--string{")

            junk, remains = line.split("--string{")

            string_index, junk = remains.split("}")

            modified_input_block[index] = modified_input_block[index].sub("--string{#{string_index.strip}}", strings[string_index.strip.to_i])

          end

        end

        return modified_input_block

      end

      input_file_contents = input_file_contents.collect { |element| element.sub("elsif", "elsuf") }

      possible_if_statements = input_file_contents.reject { |element| !element.include?("if") }

      possible_if_statements = possible_if_statements.reject { |element| element.include?("else") }

      possible_if_statements = possible_if_statements.reject { |element| element.lstrip.include?(" if ") }

      if !possible_if_statements.empty?

        if_statement_indexes = []

        possible_if_statements.each do |statement|

          if_statement_indexes << input_file_contents.dup.each_index.select { |index| input_file_contents[index] == statement }

        end

        if_statement_indexes = [0] + if_statement_indexes.flatten + [-1]

        controlregexp = /(while |def | do )/

        modified_input_contents, extracted_statements = extract_if_blocks(if_statement_indexes, input_file_contents.clone)

        joined_blocks = extracted_statements.collect { |element| element.join }

        if_statements = joined_blocks.reject { |element| element.index(controlregexp) != nil }

        rejected_elements = joined_blocks - if_statements

        rejected_elements_index = []

        rejected_elements.each do |element|

          rejected_elements_index << joined_blocks.each_index.select { |index| joined_blocks[index] == element }

        end

        if_blocks_index = (0...extracted_statements.length).to_a

        rejected_elements_index = rejected_elements_index.flatten

        if_blocks_index -= rejected_elements_index

        modified_if_statements = if_statements.collect { |string| convert_string_to_array(string, temporary_nila_file) }

        modified_if_statements = modified_if_statements.collect { |block| compile_if_syntax(block) }.reverse

        if_blocks_index = if_blocks_index.collect { |element| "--ifblock#{element}" }.reverse

        rejected_elements_index = rejected_elements_index.collect { |element| "--ifblock#{element}" }.reverse

        rejected_elements = rejected_elements.reverse

        joined_file_contents = modified_input_contents.join

        until if_blocks_index.empty? and rejected_elements_index.empty?

          if !if_blocks_index.empty?

            if joined_file_contents.include?(if_blocks_index[0])

              joined_file_contents = joined_file_contents.sub(if_blocks_index[0], modified_if_statements[0].join)

              if_blocks_index.delete_at(0)

              modified_if_statements.delete_at(0)

            else

              joined_file_contents = joined_file_contents.sub(rejected_elements_index[0], rejected_elements[0])

              rejected_elements_index.delete_at(0)

              rejected_elements.delete_at(0)

            end

          else

            joined_file_contents = joined_file_contents.sub(rejected_elements_index[0], rejected_elements[0])

            rejected_elements_index.delete_at(0)

            rejected_elements.delete_at(0)

          end

        end

      else

        joined_file_contents = input_file_contents.join

      end

      file_id = open(temporary_nila_file, 'w')

      file_id.write(joined_file_contents)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents

    end

    def compile_regular_while(input_file_contents, temporary_nila_file)

      def convert_string_to_array(input_string, temporary_nila_file)

        file_id = open(temporary_nila_file, 'w')

        file_id.write(input_string)

        file_id.close()

        line_by_line_contents = read_file_line_by_line(temporary_nila_file)

        return line_by_line_contents

      end

      def extract_while_blocks(while_statement_indexes, input_file_contents)

        possible_while_blocks = []

        while_block_counter = 0

        extracted_blocks = []

        controlregexp = /(if |while |def | do )/

        rejectionregexp = /( if | while )/

        for x in 0...while_statement_indexes.length-1

          possible_while_blocks << input_file_contents[while_statement_indexes[x]..while_statement_indexes[x+1]]

        end

        end_counter = 0

        end_index = []

        current_block = []

        possible_while_blocks.each_with_index do |block|

          current_block += block

          current_block.each_with_index do |line, index|

            if line.strip.eql? "end"

              end_counter += 1

              end_index << index

            end

          end

          if end_counter > 0

            until end_index.empty?

              array_extract = current_block[0..end_index[0]].reverse

              index_counter = 0

              array_extract.each_with_index do |line|

                break if (line.lstrip.index(controlregexp) != nil and line.lstrip.index(rejectionregexp).nil?)

                index_counter += 1

              end

              block_extract = array_extract[0..index_counter].reverse

              extracted_blocks << block_extract

              block_start = current_block.index(block_extract[0])

              block_end = current_block.index(block_extract[-1])

              current_block[block_start..block_end] = "--whileblock#{while_block_counter}"

              while_block_counter += 1

              end_counter = 0

              end_index = []

              current_block.each_with_index do |line, index|

                if line.strip.eql? "end"

                  end_counter += 1

                  end_index << index

                end

              end

            end

          end

        end

        return current_block, extracted_blocks

      end

      def compile_while_syntax(input_block)

        modified_input_block = input_block.dup

        strings = []

        string_counter = 0

        input_block.each_with_index do |line, index|

          if line.include?("\"")

            opening_quotes = line.index("\"")

            string_extract = line[opening_quotes..line.index("\"", opening_quotes+1)]

            strings << string_extract

            modified_input_block[index] = modified_input_block[index].sub(string_extract, "--string{#{string_counter}}")

            string_counter += 1

          end

        end

        input_block = modified_input_block

        starting_line = input_block[0]

        starting_line = starting_line + "\n" if starting_line.lstrip == starting_line

        junk, condition = starting_line.split("while")

        input_block[0] = "whaaleskey (#{condition.lstrip.rstrip.gsub("?", "")}) {\n"

        input_block[-1] = input_block[-1].lstrip.sub("end", "}")

        modified_input_block = input_block.dup

        input_block.each_with_index do |line, index|

          if line.include?("--string{")

            junk, remains = line.split("--string{")

            string_index, junk = remains.split("}")

            modified_input_block[index] = modified_input_block[index].sub("--string{#{string_index.strip}}", strings[string_index.strip.to_i])

          end

        end

        return modified_input_block

      end

      possible_while_statements = input_file_contents.reject { |element| !element.include?("while") }

      if !possible_while_statements.empty?

        while_statement_indexes = []

        possible_while_statements.each do |statement|

          while_statement_indexes << input_file_contents.dup.each_index.select { |index| input_file_contents[index] == statement }

        end

        while_statement_indexes = [0] + while_statement_indexes.flatten + [-1]

        controlregexp = /(if |def | do )/

        modified_input_contents, extracted_statements = extract_while_blocks(while_statement_indexes, input_file_contents.clone)

        joined_blocks = extracted_statements.collect { |element| element.join }

        while_statements = joined_blocks.reject { |element| element.index(controlregexp) != nil }

        rejected_elements = joined_blocks - while_statements

        rejected_elements_index = []

        rejected_elements.each do |element|

          rejected_elements_index << joined_blocks.each_index.select { |index| joined_blocks[index] == element }

        end

        while_blocks_index = (0...extracted_statements.length).to_a

        rejected_elements_index = rejected_elements_index.flatten

        while_blocks_index -= rejected_elements_index

        modified_while_statements = while_statements.collect { |string| convert_string_to_array(string, temporary_nila_file) }

        modified_while_statements = modified_while_statements.collect { |block| compile_while_syntax(block) }.reverse

        while_blocks_index = while_blocks_index.collect { |element| "--whileblock#{element}" }.reverse

        rejected_elements_index = rejected_elements_index.collect { |element| "--whileblock#{element}" }.reverse

        rejected_elements = rejected_elements.reverse

        joined_file_contents = modified_input_contents.join

        until while_blocks_index.empty? and rejected_elements_index.empty?

          if !while_blocks_index.empty?

            if joined_file_contents.include?(while_blocks_index[0])

              joined_file_contents = joined_file_contents.sub(while_blocks_index[0], modified_while_statements[0].join)

              while_blocks_index.delete_at(0)

              modified_while_statements.delete_at(0)

            else

              joined_file_contents = joined_file_contents.sub(rejected_elements_index[0], rejected_elements[0])

              rejected_elements_index.delete_at(0)

              rejected_elements.delete_at(0)

            end

          else

            joined_file_contents = joined_file_contents.sub(rejected_elements_index[0], rejected_elements[0])

            rejected_elements_index.delete_at(0)

            rejected_elements.delete_at(0)

          end

        end

      else

        joined_file_contents = input_file_contents.join

      end

      file_id = open(temporary_nila_file, 'w')

      file_id.write(joined_file_contents)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents

    end

    def compile_regular_for(input_file_contents, temporary_nila_file)

      def convert_string_to_array(input_string, temporary_nila_file)

        file_id = open(temporary_nila_file, 'w')

        file_id.write(input_string)

        file_id.close()

        line_by_line_contents = read_file_line_by_line(temporary_nila_file)

        return line_by_line_contents

      end

      def extract_for_blocks(for_statement_indexes, input_file_contents)

        possible_for_blocks = []

        for_block_counter = 0

        extracted_blocks = []

        controlregexp = /(if |while |def |for | do )/

        rejectionregexp = /( if | while )/

        for x in 0...for_statement_indexes.length-1

          possible_for_blocks << input_file_contents[for_statement_indexes[x]..for_statement_indexes[x+1]]

        end

        end_counter = 0

        end_index = []

        current_block = []

        possible_for_blocks.each_with_index do |block|

          current_block += block

          current_block.each_with_index do |line, index|

            if line.strip.eql? "end"

              end_counter += 1

              end_index << index

            end

          end

          if end_counter > 0

            until end_index.empty?

              array_extract = current_block[0..end_index[0]].reverse

              index_counter = 0

              array_extract.each_with_index do |line|

                break if (line.lstrip.index(controlregexp) != nil and line.lstrip.index(rejectionregexp).nil?)

                index_counter += 1

              end

              block_extract = array_extract[0..index_counter].reverse

              extracted_blocks << block_extract

              block_start = current_block.index(block_extract[0])

              block_end = current_block.index(block_extract[-1])

              current_block[block_start..block_end] = "--forblock#{for_block_counter}"

              for_block_counter += 1

              end_counter = 0

              end_index = []

              current_block.each_with_index do |line, index|

                if line.strip.eql? "end"

                  end_counter += 1

                  end_index << index

                end

              end

            end

          end

        end

        return current_block, extracted_blocks

      end

      def compile_for_syntax(input_block)

        def compile_condition(input_condition, input_block)

          variable,array_name = input_condition.split("in")

          if array_name.strip.include?("[") and array_name.strip.include?("]")

            replacement_array = "_ref1 = #{array_name.strip}\n\n"

            replacement_string = "#{variable.strip} = _ref1[_i];\n\n"

            input_block = [replacement_array] + input_block.insert(1,replacement_string)

            input_block[1] = "for (_i = 0, _j = _ref1.length; _i < _j; _i += 1) {\n\n"

          elsif array_name.strip.include?("..")

            array_type = if array_name.strip.include?("...") then 0 else 1 end

            if array_type == 0

              num1,num2 = array_name.strip.split("...")

              input_block[0] = "for (#{variable.strip} = #{num1}, _j = #{num2}; #{variable.strip} <= _j; #{variable.strip} += 1) {\n\n"

            else

              num1,num2 = array_name.strip.split("..")

              input_block[0] = "for (#{variable.strip} = #{num1}, _j = #{num2}; #{variable.strip} < _j; #{variable.strip} += 1) {\n\n"

            end

          else

            input_block[0] = "for (_i = 0, _j = #{array_name.strip}.length; _i < _j; _i += 1) {\n\n"

            input_block = input_block.insert(1,"#{variable.strip} = #{array_name.strip}[_i];\n\n")

          end

          return input_block

        end

        modified_input_block = input_block.dup

        strings = []

        string_counter = 0

        input_block.each_with_index do |line, index|

          if line.include?("\"")

            opening_quotes = line.index("\"")

            string_extract = line[opening_quotes..line.index("\"", opening_quotes+1)]

            strings << string_extract

            modified_input_block[index] = modified_input_block[index].sub(string_extract, "--string{#{string_counter}}")

            string_counter += 1

          end

        end

        input_block = modified_input_block

        starting_line = input_block[0]

        starting_line = starting_line + "\n" if starting_line.lstrip == starting_line

        junk, condition = starting_line.split("for")

        input_block[-1] = input_block[-1].lstrip.sub("end", "}")

        input_block = compile_condition(condition,input_block)

        modified_input_block = input_block.dup

        input_block.each_with_index do |line, index|

          if line.include?("--string{")

            junk, remains = line.split("--string{")

            string_index, junk = remains.split("}")

            modified_input_block[index] = modified_input_block[index].sub("--string{#{string_index.strip}}", strings[string_index.strip.to_i])

          end

        end

        return modified_input_block

      end

      possible_for_statements = input_file_contents.reject { |element| !element.include?("for") }

      possible_for_statements = possible_for_statements.reject {|element| element.include?("for (")}

      if !possible_for_statements.empty?

        for_statement_indexes = []

        possible_for_statements.each do |statement|

          for_statement_indexes << input_file_contents.dup.each_index.select { |index| input_file_contents[index] == statement }

        end

        for_statement_indexes = [0] + for_statement_indexes.flatten + [-1]

        controlregexp = /(if |def |while | do )/

        modified_input_contents, extracted_statements = extract_for_blocks(for_statement_indexes, input_file_contents.clone)

        joined_blocks = extracted_statements.collect { |element| element.join }

        for_statements = joined_blocks.reject { |element| element.index(controlregexp) != nil }

        rejected_elements = joined_blocks - for_statements

        rejected_elements_index = []

        rejected_elements.each do |element|

          rejected_elements_index << joined_blocks.each_index.select { |index| joined_blocks[index] == element }

        end

        for_blocks_index = (0...extracted_statements.length).to_a

        rejected_elements_index = rejected_elements_index.flatten

        for_blocks_index -= rejected_elements_index

        modified_for_statements = for_statements.collect { |string| convert_string_to_array(string, temporary_nila_file) }

        modified_for_statements = modified_for_statements.collect { |block| compile_for_syntax(block) }.reverse

        for_blocks_index = for_blocks_index.collect { |element| "--forblock#{element}" }.reverse

        rejected_elements_index = rejected_elements_index.collect { |element| "--forblock#{element}" }.reverse

        rejected_elements = rejected_elements.reverse

        joined_file_contents = modified_input_contents.join

        until for_blocks_index.empty? and rejected_elements_index.empty?

          if !for_blocks_index.empty?

            if joined_file_contents.include?(for_blocks_index[0])

              joined_file_contents = joined_file_contents.sub(for_blocks_index[0], modified_for_statements[0].join)

              for_blocks_index.delete_at(0)

              modified_for_statements.delete_at(0)

            else

              joined_file_contents = joined_file_contents.sub(rejected_elements_index[0], rejected_elements[0].join)

              rejected_elements_index.delete_at(0)

              rejected_elements.delete_at(0)

            end

          else

            joined_file_contents = joined_file_contents.sub(rejected_elements_index[0], rejected_elements[0])

            rejected_elements_index.delete_at(0)

            rejected_elements.delete_at(0)

          end

        end

      else

        joined_file_contents = input_file_contents.join

      end

      file_id = open(temporary_nila_file, 'w')

      file_id.write(joined_file_contents)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents

    end

    def compile_loop_keyword(input_file_contents,temporary_nila_file)

      def convert_string_to_array(input_string, temporary_nila_file)

        file_id = open(temporary_nila_file, 'w')

        file_id.write(input_string)

        file_id.close()

        line_by_line_contents = read_file_line_by_line(temporary_nila_file)

        return line_by_line_contents

      end

      def extract_loop_blocks(loop_statement_indexes, input_file_contents)

        possible_loop_blocks = []

        loop_block_counter = 0

        extracted_blocks = []

        controlregexp = /(if |while |def |loop )/

        rejectionregexp = /( if | while )/

        for x in 0...loop_statement_indexes.length-1

          possible_loop_blocks << input_file_contents[loop_statement_indexes[x]..loop_statement_indexes[x+1]]

        end

        end_counter = 0

        end_index = []

        current_block = []

        possible_loop_blocks.each_with_index do |block|

          current_block += block

          current_block.each_with_index do |line, index|

            if line.strip.eql? "end"

              end_counter += 1

              end_index << index

            end

          end

          if end_counter > 0

            until end_index.empty?

              array_extract = current_block[0..end_index[0]].reverse

              index_counter = 0

              array_extract.each_with_index do |line|

                break if (line.lstrip.index(controlregexp) != nil and line.lstrip.index(rejectionregexp).nil?)

                index_counter += 1

              end

              block_extract = array_extract[0..index_counter].reverse

              extracted_blocks << block_extract

              block_start = current_block.index(block_extract[0])

              block_end = current_block.index(block_extract[-1])

              current_block[block_start..block_end] = "--loopblock#{loop_block_counter}"

              loop_block_counter += 1

              end_counter = 0

              end_index = []

              current_block.each_with_index do |line, index|

                if line.strip.eql? "end"

                  end_counter += 1

                  end_index << index

                end

              end

            end

          end

        end

        return current_block, extracted_blocks

      end

      def compile_loop_syntax(input_block)

        modified_input_block = input_block.dup

        strings = []

        string_counter = 0

        input_block.each_with_index do |line, index|

          if line.include?("\"")

            opening_quotes = line.index("\"")

            string_extract = line[opening_quotes..line.index("\"", opening_quotes+1)]

            strings << string_extract

            modified_input_block[index] = modified_input_block[index].sub(string_extract, "--string{#{string_counter}}")

            string_counter += 1

          end

        end

        input_block = modified_input_block

        starting_line = input_block[0]

        starting_line = starting_line + "\n" if starting_line.lstrip == starting_line

        input_block[0] = "whaaleskey (true) {\n"

        input_block[-1] = input_block[-1].lstrip.sub("end", "}")

        modified_input_block = input_block.dup

        input_block.each_with_index do |line, index|

          if line.include?("--string{")

            junk, remains = line.split("--string{")

            string_index, junk = remains.split("}")

            modified_input_block[index] = modified_input_block[index].sub("--string{#{string_index.strip}}", strings[string_index.strip.to_i])

          end

        end

        return modified_input_block

      end

      possible_loop_statements = input_file_contents.reject { |element| !element.include?("loop") }

      if !possible_loop_statements.empty?

        loop_statement_indexes = []

        possible_loop_statements.each do |statement|

          loop_statement_indexes << input_file_contents.dup.each_index.select { |index| input_file_contents[index] == statement }

        end

        loop_statement_indexes = [0] + loop_statement_indexes.flatten + [-1]

        controlregexp = /(if |def )/

        modified_input_contents, extracted_statements = extract_loop_blocks(loop_statement_indexes, input_file_contents.clone)

        joined_blocks = extracted_statements.collect { |element| element.join }

        loop_statements = joined_blocks.reject { |element| element.index(controlregexp) != nil }

        rejected_elements = joined_blocks - loop_statements

        rejected_elements_index = []

        rejected_elements.each do |element|

          rejected_elements_index << joined_blocks.each_index.select { |index| joined_blocks[index] == element }

        end

        loop_blocks_index = (0...extracted_statements.length).to_a

        rejected_elements_index = rejected_elements_index.flatten

        loop_blocks_index -= rejected_elements_index

        modified_loop_statements = loop_statements.collect { |string| convert_string_to_array(string, temporary_nila_file) }

        modified_loop_statements = modified_loop_statements.collect { |block| compile_loop_syntax(block) }.reverse

        loop_blocks_index = loop_blocks_index.collect { |element| "--loopblock#{element}" }.reverse

        rejected_elements_index = rejected_elements_index.collect { |element| "--loopblock#{element}" }.reverse

        rejected_elements = rejected_elements.reverse

        joined_file_contents = modified_input_contents.join

        until loop_blocks_index.empty? and rejected_elements_index.empty?

          if !loop_blocks_index.empty?

            if joined_file_contents.include?(loop_blocks_index[0])

              joined_file_contents = joined_file_contents.sub(loop_blocks_index[0], modified_loop_statements[0].join)

              loop_blocks_index.delete_at(0)

              modified_loop_statements.delete_at(0)

            else

              joined_file_contents = joined_file_contents.sub(rejected_elements_index[0], rejected_elements[0].join)

              rejected_elements_index.delete_at(0)

              rejected_elements.delete_at(0)

            end

          else

            joined_file_contents = joined_file_contents.sub(rejected_elements_index[0], rejected_elements[0].join)

            rejected_elements_index.delete_at(0)

            rejected_elements.delete_at(0)

          end

        end

      else

        joined_file_contents = input_file_contents.join

      end

      file_id = open(temporary_nila_file, 'w')

      file_id.write(joined_file_contents)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents

    end

    def ignore_statement_modifiers(input_block)

      modified_input_block = input_block.dup

      rejectionregexp = /( if | while )/

      rejected_lines = {}

      rejected_line_counter = 0

      input_block.each_with_index do |line, index|

        if line.lstrip.index(rejectionregexp) != nil

          rejected_lines["--rejected{#{rejected_line_counter}}\n\n"] = line

          modified_input_block[index] = "--rejected{#{rejected_line_counter}}\n\n"

          rejected_line_counter += 1

        end

      end

      return modified_input_block, rejected_lines

    end

    def replace_statement_modifiers(input_block, rejected_lines)

      unless rejected_lines.empty?

        rejected_replacements = rejected_lines.keys

        loc = 0

        indices = []

        index_counter = 0

        rejected_replacements.each do |replacement_string|

          input_block.each_with_index do |line, index|

            break if line.include?(replacement_string.rstrip)

            index_counter += 1

          end

          indices << index_counter

          index_counter = 0

        end

        indices.each_with_index do |location, index|

          input_block[location] = rejected_lines.values[index] + "\n\n"

        end

      end

      return input_block

    end

    file_contents = compile_ternary_if(input_file_contents)

    file_contents, rejected_lines = ignore_statement_modifiers(file_contents)

    file_contents = replace_unless_until(file_contents)

    file_contents = compile_regular_if(file_contents, temporary_nila_file)

    file_contents = compile_regular_for(file_contents, temporary_nila_file)

    file_contents = compile_regular_while(file_contents, temporary_nila_file)

    file_contents = compile_loop_keyword(file_contents,temporary_nila_file)

    file_contents = replace_statement_modifiers(file_contents, rejected_lines)

    file_contents = compile_inline_conditionals(file_contents, temporary_nila_file)

    return file_contents

  end

  def compile_case_statement(input_file_contents,temporary_nila_file)

    # This method compiles simple Ruby style case statements to Javascript
    # equivalent switch case statements

    # For an example, look at shark/test_files/case.nila

    def replace_strings(input_string)

      string_counter = 0

      if input_string.count("\"") % 2 == 0

        while input_string.include?("\"")

          string_extract = input_string[input_string.index("\"")..input_string.index("\"",input_string.index("\"")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

      end

      if input_string.count("'") % 2 == 0

        while input_string.include?("'")

          string_extract = input_string[input_string.index("'")..input_string.index("'",input_string.index("'")+1)]

          input_string = input_string.sub(string_extract,"--repstring#{string_counter}")

          string_counter += 1

        end

      end

      return input_string

    end

    def compile_when_statement(input_block)

      condition,body = input_block[0],input_block[1..-1]

      if replace_strings(condition.split("when ")[1]).include?(",")

        condition_cases = condition.split("when ")[1].split(",").collect {|element| element.strip}

        case_replacement = []

        condition_cases.each do |ccase|

          case_replacement << "case #{ccase}:%$%$ {\n\n"

          case_replacement << body.collect {|element| "  " + element.strip + "\n\n"}

          case_replacement << "  break\n%$%$\n}\n"

        end

      else

        case_replacement = []

        condition_case = condition.split("when ")[1].strip

        case_replacement << "case #{condition_case}:%$%$ {\n\n"

        case_replacement << body.collect {|element| "  " + element.strip + "\n\n"}

        case_replacement << "  break\n%$%$\n}\n"

      end

      return case_replacement.join

    end

    modified_file_contents = input_file_contents.clone

    possible_case_statements = input_file_contents.reject {|element| !element.include?("case ")}

    case_statements = []

    possible_case_statements.each do |statement|

      starting_index = input_file_contents.index(statement)

      index = starting_index

      until input_file_contents[index].strip.eql?("end")

        index += 1

      end

      case_statements << input_file_contents[starting_index..index].collect {|element| element.clone}.clone

    end

    legacy = case_statements.collect {|element| element.clone}

    replacement_strings = []

    case_statements.each do |statement_block|

      condition = statement_block[0].split("case")[1].strip

      statement_block[0] = "switch(#{condition}) {\n\n"

      when_statements = statement_block.reject {|element| !replace_strings(element).include?("when")}

      when_statements_index = []

      when_statements.each do |statement|

        when_statements_index << statement_block.each_index.select{|index| statement_block[index] == statement}

      end

      when_statements_index = when_statements_index.flatten

      if replace_strings(statement_block.join).include?("else\n")

        else_statement = statement_block.reject {|element| !replace_strings(element).strip.eql?("else")}

        else_block = statement_block[statement_block.index(else_statement[0])+1...-1]

        when_statements_index = when_statements_index + statement_block.each_index.select {|index| statement_block[index] == else_statement[0] }.to_a

        when_statements_index = when_statements_index.flatten

        statement_block[statement_block.index(else_statement[0])..-1] = ["default: %$%$ {\n\n",else_block.collect{|element| "  " + element.strip + "\n\n"},"%$%$\n}\n\n}\n\n"].flatten

        when_statement_blocks = []

        when_statements.each_with_index do |statement,ind|

          when_block = statement_block[when_statements_index[ind]...when_statements_index[ind+1]]

          when_statement_blocks << when_block

        end

        replacement_blocks = when_statement_blocks.collect {|element| compile_when_statement(element)}

      else

        statement_block[-1] = "}\n\n" if statement_block[-1].strip.eql?("end")

        when_statement_blocks = []

        when_statements_index << -1

        when_statements.each_with_index do |statement,ind|

          when_block = statement_block[when_statements_index[ind]...when_statements_index[ind+1]]

          when_statement_blocks << when_block

        end

        replacement_blocks = when_statement_blocks.collect {|element| compile_when_statement(element)}

      end

      statement_block = statement_block.join

      when_statement_blocks.each_with_index do |blck,index|

        statement_block = statement_block.sub(blck.join,replacement_blocks[index])

      end

      replacement_strings << statement_block

    end

    joined_file_contents = modified_file_contents.join

    legacy.each_with_index do |statement,index|

      joined_file_contents = joined_file_contents.sub(statement.join,replacement_strings[index])

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(joined_file_contents)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    return line_by_line_contents

  end

  def compile_loops(input_file_contents,temporary_nila_file)

    def compile_times_loop(input_file_contents,temporary_nila_file)

      def compile_one_line_blocks(input_block)

        block_parameters, block_contents = input_block[1...-1].split("|",2)[1].split("|",2)

        compiled_block = "(function(#{block_parameters.lstrip.rstrip}) {\n\n  #{block_contents.strip} \n\n}(_i))_!;\n"

        return compiled_block

      end

      def extract_variable_names(input_file_contents)

        variables = []

        input_file_contents = input_file_contents.collect { |element| element.gsub("==", "equalequal") }

        input_file_contents = input_file_contents.collect { |element| element.gsub("!=", "notequal") }

        input_file_contents = input_file_contents.collect { |element| element.gsub("+=", "plusequal") }

        input_file_contents = input_file_contents.collect { |element| element.gsub("-=", "minusequal") }

        input_file_contents = input_file_contents.collect { |element| element.gsub("*=", "multiequal") }

        input_file_contents = input_file_contents.collect { |element| element.gsub("/=", "divequal") }

        input_file_contents = input_file_contents.collect { |element| element.gsub("%=", "modequal") }

        input_file_contents = input_file_contents.collect { |element| element.gsub("=~", "matchequal") }

        input_file_contents = input_file_contents.collect { |element| element.gsub(">=", "greatequal") }

        input_file_contents = input_file_contents.collect { |element| element.gsub("<=", "lessyequal") }

        javascript_regexp = /(if |while |for )/

        for x in 0...input_file_contents.length

          current_row = input_file_contents[x]

          if current_row.include?("=") and current_row.index(javascript_regexp) == nil

            current_row = current_row.rstrip + "\n"

            current_row_split = current_row.split("=")

            for y in 0...current_row_split.length

              current_row_split[y] = current_row_split[y].strip


            end

            if current_row_split[0].include?("[") or current_row_split[0].include?("(")

              current_row_split[0] = current_row_split[0][0...current_row_split[0].index("[")]

            end

            variables << current_row_split[0]


          end

          input_file_contents[x] = current_row

        end

        variables += ["_i","_j"]

        variables = variables.flatten

        return variables.uniq

      end

      possible_times_loop = input_file_contents.reject{ |element| !element.include?(".times")}

      multiline_times_loop = possible_times_loop.reject {|element| !element.include?(" do ")}

      unless multiline_times_loop.empty?

        multiline_times_loop.each do |starting_line|

          index_counter = starting_counter = input_file_contents.index(starting_line)

          line = starting_line

          until line.strip.eql?("end")

            index_counter += 1

            line = input_file_contents[index_counter]

          end

          loop_extract = input_file_contents[starting_counter..index_counter]

          file_extract = input_file_contents[0..index_counter]

          file_variables = extract_variable_names(file_extract)

          block_variables = extract_variable_names(loop_extract)

          var_need_of_declaration = file_variables-block_variables-["_i","_j"]

          loop_condition, block = loop_extract.join.split(" do ")

          block = block.split("end")[0]

          replacement_string = "#{loop_condition.rstrip} {#{block.strip}}"

          input_file_contents[starting_counter..index_counter] = replacement_string

        end

      end

      possible_times_loop = input_file_contents.reject{ |element| !element.include?(".times")}

      oneliner_times_loop = possible_times_loop.reject {|element| !element.include?("{") and !element.include?("}")}

      loop_variables = []

      modified_file_contents = input_file_contents.clone

      unless oneliner_times_loop.empty?

        oneliner_times_loop.each do |loop|

          original_loop = loop.clone

          string_counter = 1

          extracted_string = []

          while loop.include?("\"")

            string_extract = loop[loop.index("\"")..loop.index("\"",loop.index("\"")+1)]

            extracted_string << string_extract

            loop = loop.sub(string_extract,"--repstring#{string_counter}")

            string_counter += 1

          end

          block_extract = loop[loop.index("{")..loop.index("}")]

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

          times_counter = loop.split(".times")[0].lstrip

          times_counter = times_counter[1...-1] if times_counter.include?("(") and times_counter.include?(")")

          replacement_string = "for (_i = 0, _j = #{times_counter}; _i < _j; _i += 1) {\n\n#{compiled_block}\n\n}"

          modified_file_contents[input_file_contents.index(original_loop)] = replacement_string

        end

        loop_variables = ["_i","_j"]

      end

      file_id = open(temporary_nila_file, 'w')

      file_id.write(modified_file_contents.join)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents,loop_variables

    end

    file_contents,loop_variables = compile_times_loop(input_file_contents,temporary_nila_file)

    return file_contents,loop_variables

  end

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

  def add_semicolons(input_file_contents)

    def comment(input_string)

      if input_string.include?("--single_line_comment")

        true

      elsif input_string.include?("--multiline_comment")

        true

      else

        false

      end

    end

    reject_regexp = /(function |Euuf |if |else|elsuf|switch |case|while |whaaleskey |for )/

    modified_file_contents = input_file_contents.dup

    input_file_contents.each_with_index do |line,index|

      if line.index(reject_regexp) == nil

        if !comment(line)

          if !line.lstrip.eql?("")

            if !line.lstrip.eql?("}\n")

              if !line.lstrip.eql?("}\n\n")

                if line.rstrip[-1] != "[" and line.rstrip[-1] != "{" and line.rstrip[-1] != "," and line.rstrip[-1] != ";"

                  modified_file_contents[index] = line.rstrip + ";\n\n"

                end

              end

            end

          end

        end

      end

    end

    modified_file_contents

  end

  def compile_comments(input_file_contents, comments, temporary_nila_file)

    #This method converts Nila comments into pure Javascript comments. This method
    #handles both single line and multiline comments.

    file_contents_as_string = input_file_contents.join

    single_line_comments = comments[0]

    multiline_comments = comments[1]

    single_line_comment_counter = 1

    multi_line_comment_counter = 1

    ignorable_keywords = [/if/, /while/, /function/]

    dummy_replacement_words = ["eeuuff", "whaalesskkey", "conffoolotion"]

    for x in 0...single_line_comments.length

      current_singleline_comment = "--single_line_comment[#{single_line_comment_counter}]"

      replacement_singleline_string = single_line_comments[x].sub("#", "//")

      ignorable_keywords.each_with_index do |keyword, index|

        if replacement_singleline_string.index(keyword) != nil

          replacement_singleline_string = replacement_singleline_string.sub(keyword.inspect[1...-1], dummy_replacement_words[index])

        end

      end

      file_contents_as_string = file_contents_as_string.sub(current_singleline_comment, replacement_singleline_string)

      single_line_comment_counter += 1


    end

    for y in 0...multiline_comments.length

      current_multiline_comment = "--multiline_comment[#{multi_line_comment_counter}]"

      replacement_multiline_string = multiline_comments[y].sub("=begin", "/*\n")

      replacement_multiline_string = replacement_multiline_string.sub("=end", "\n*/")

      ignorable_keywords.each_with_index do |keyword, index|

        if replacement_multiline_string.index(keyword) != nil

          replacement_multiline_string = replacement_multiline_string.sub(keyword.inspect[1...-1], dummy_replacement_words[index])

        end

      end

      file_contents_as_string = file_contents_as_string.sub(current_multiline_comment, replacement_multiline_string)

      multi_line_comment_counter += 1

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(file_contents_as_string)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    line_by_line_contents

  end

  def pretty_print_javascript(javascript_file_contents, temporary_nila_file,declarable_variables)

    def reset_tabs(input_file_contents)

      #This method removes all the predefined tabs to avoid problems in
      #later parts of the beautifying process.

      for x in 0...input_file_contents.length

        current_row = input_file_contents[x]

        if !current_row.eql?("\n")

          current_row = current_row.lstrip

        end

        input_file_contents[x] = current_row


      end

      return input_file_contents

    end

    def find_all_matching_indices(input_string, pattern)

      locations = []

      index = input_string.index(pattern)

      while index != nil

        locations << index

        index = input_string.index(pattern, index+1)


      end

      return locations


    end

    def convert_string_to_array(input_string, temporary_nila_file)

      file_id = open(temporary_nila_file, 'w')

      file_id.write(input_string)

      file_id.close()

      line_by_line_contents = read_file_line_by_line(temporary_nila_file)

      return line_by_line_contents

    end

    def fix_newlines(file_contents)

      def extract_blocks(file_contents)

        javascript_regexp = /(if |while |for |case |default:|switch\(|function\(|((=|:)\s+\{))/

        block_starting_lines = file_contents.dup.reject { |element| element.index(javascript_regexp).nil? }[1..-1]

        block_starting_lines = block_starting_lines.reject { |element| element.include?("    ") }

        initial_starting_lines = block_starting_lines.dup

        starting_line_indices = []

        block_starting_lines.each do |line|

          starting_line_indices << file_contents.index(line)

        end

        block_ending_lines = file_contents.dup.each_index.select { |index| (file_contents[index].eql? "  }\n" or file_contents[index].eql? "  };\n" or file_contents[index].lstrip.eql?("});\n"))}

        modified_file_contents = file_contents.dup

        code_blocks = []

        starting_index = starting_line_indices[0]

        begin

          for x in 0...initial_starting_lines.length

            code_blocks << modified_file_contents[starting_index..block_ending_lines[0]]

            modified_file_contents[starting_index..block_ending_lines[0]] = []

            modified_file_contents.insert(starting_index, "  *****")

            block_starting_lines = modified_file_contents.dup.reject { |element| element.index(javascript_regexp).nil? }[1..-1]

            block_starting_lines = block_starting_lines.reject { |element| element.include?("    ") }

            starting_line_indices = []

            block_starting_lines.each do |line|

              starting_line_indices << modified_file_contents.index(line)

            end

            block_ending_lines = modified_file_contents.dup.each_index.select { |index| (modified_file_contents[index].eql? "  }\n" or modified_file_contents[index].eql? "  };\n" or modified_file_contents[index].lstrip.eql?("});\n")) }

            starting_index = starting_line_indices[0]

          end

        #rescue TypeError
        #
        #  puts "Whitespace was left unfixed!"
        #
        #rescue ArgumentError
        #
        #  puts "Whitespace was left unfixed!"

        end

        return modified_file_contents, code_blocks

      end

      compact_contents = file_contents.reject { |element| element.lstrip.eql? "" }

      compact_contents, code_blocks = extract_blocks(compact_contents)

      processed_contents = compact_contents[1...-1].collect { |line| line+"\n" }

      compact_contents = [compact_contents[0]] + processed_contents + [compact_contents[-1]]

      code_block_locations = compact_contents.each_index.select { |index| compact_contents[index].eql? "  *****\n" }

      initial_locations = code_block_locations.dup

      starting_index = code_block_locations[0]

      for x in 0...initial_locations.length

        code_blocks[x][-1] = code_blocks[x][-1] + "\n"

        compact_contents = compact_contents[0...starting_index] + code_blocks[x] + compact_contents[starting_index+1..-1]

        code_block_locations = compact_contents.each_index.select { |index| compact_contents[index].eql? "  *****\n" }

        starting_index = code_block_locations[0]

      end

      return compact_contents

    end

    def roll_blocks(input_file_contents, code_block_starting_locations)

      if !code_block_starting_locations.empty?

        controlregexp = /(if |for |while |case |default:|switch\(|,function\(|\(function\(|= function\(|((=|:)\s+\{))/

        code_block_starting_locations = [0, code_block_starting_locations, -1].flatten

        possible_blocks = []

        block_counter = 0

        extracted_blocks = []

        for x in 0...code_block_starting_locations.length-1

          possible_blocks << input_file_contents[code_block_starting_locations[x]..code_block_starting_locations[x+1]]

          if possible_blocks.length > 1

            possible_blocks[-1] = possible_blocks[-1][1..-1]

          end

        end

        end_counter = 0

        end_index = []

        current_block = []

        possible_blocks.each_with_index do |block|

          if !block[0].eql?(current_block[-1])

            current_block += block

          else

            current_block += block[1..-1]

          end

          current_block.each_with_index do |line, index|

            if line.lstrip.eql? "}\n" or line.lstrip.eql?("};\n") or line.lstrip.include?("_!;\n") or line.lstrip.include?("});\n")

              end_counter += 1

              end_index << index

            end

          end

          if end_counter > 0

            until end_index.empty?

              array_extract = current_block[0..end_index[0]].reverse

              index_counter = 0

              array_extract.each_with_index do |line|

                break if line.index(controlregexp) != nil

                index_counter += 1

              end

              block_extract = array_extract[0..index_counter].reverse

              extracted_blocks << block_extract

              block_start = current_block.index(block_extract[0])

              block_end = current_block.index(block_extract[-1])

              current_block[block_start..block_end] = "--block#{block_counter}\n"

              block_counter += 1

              end_counter = 0

              end_index = []

              current_block.each_with_index do |line, index|

                if line.lstrip.eql? "}\n" or line.lstrip.eql?("};\n") or line.lstrip.include?("_!;\n") or line.lstrip.include?("});\n")

                  end_counter += 1

                  end_index << index

                end

              end

            end

          end

        end

        return current_block, extracted_blocks

      else

        return input_file_contents, []

      end

    end

    def fix_syntax_indentation(input_file_contents)

      fixableregexp = /(else |elsuf )/

      need_fixes = input_file_contents.reject { |line| line.index(fixableregexp).nil? }

      need_fixes.each do |fix|

        input_file_contents[input_file_contents.index(fix)] = input_file_contents[input_file_contents.index(fix)].sub("  ", "")

      end

      return input_file_contents

    end

    def replace_ignored_words(input_string)

      ignorable_keywords = [/if/, /while/, /function/,/function/]

      dummy_replacement_words = ["eeuuff", "whaalesskkey", "conffoolotion"]

      dummy_replacement_words.each_with_index do |word, index|

        input_string = input_string.sub(word, ignorable_keywords[index].inspect[1...-1])

      end

      return input_string

    end

    javascript_regexp = /(if |for |while |case |default:|switch\(|\(function\(|= function\(|((=|:)\s+\{))/

    if declarable_variables.length > 0

      declaration_string = "var " + declarable_variables.flatten.uniq.sort.join(", ") + ";\n\n"

      javascript_file_contents = [declaration_string,javascript_file_contents].flatten

    end

    javascript_file_contents = javascript_file_contents.collect { |element| element.sub("Euuf", "if") }

    javascript_file_contents = javascript_file_contents.collect { |element| element.sub("whaaleskey", "while") }

    javascript_file_contents = reset_tabs(javascript_file_contents)

    starting_locations = []

    javascript_file_contents.each_with_index do |line, index|

      if line.index(javascript_regexp) != nil

        starting_locations << index

      end

    end

    remaining_file_contents, blocks = roll_blocks(javascript_file_contents, starting_locations)

    joined_file_contents = ""

    if !blocks.empty?

      remaining_file_contents = remaining_file_contents.collect { |element| "  " + element }

      main_blocks = remaining_file_contents.reject { |element| !element.include?("--block") }

      main_block_numbers = main_blocks.collect { |element| element.split("--block")[1] }

      modified_blocks = main_blocks.dup

      soft_tabs = "  "

      for x in (0...main_blocks.length)

        soft_tabs_counter = 1

        current_block = blocks[main_block_numbers[x].to_i]

        current_block = [soft_tabs + current_block[0]] + current_block[1...-1] + [soft_tabs*(soft_tabs_counter)+current_block[-1]]

        soft_tabs_counter += 1

        current_block = [current_block[0]] + current_block[1...-1].collect { |element| soft_tabs*(soft_tabs_counter)+element } + [current_block[-1]]

        nested_block = current_block.clone.reject { |row| !row.include?("--block") }

        nested_block = nested_block.collect { |element| element.split("--block")[1] }

        nested_block = nested_block.collect { |element| element.rstrip.to_i }

        modified_nested_block = nested_block.clone

        current_block = current_block.join("\n")

        until modified_nested_block.empty?

          nested_block.each do |block_index|

            nested_block_contents = blocks[block_index]

            nested_block_contents = nested_block_contents[0...-1] + [soft_tabs*(soft_tabs_counter)+nested_block_contents[-1]]

            soft_tabs_counter += 1

            nested_block_contents = [nested_block_contents[0]] + nested_block_contents[1...-1].collect { |element| soft_tabs*(soft_tabs_counter)+element } + [nested_block_contents[-1]]

            nested_block_contents = nested_block_contents.reject { |element| element.gsub(" ", "").eql?("") }

            current_block = current_block.sub("--block#{block_index}", nested_block_contents.join)

            blocks[block_index] = nested_block_contents

            modified_nested_block.delete_at(0)

            soft_tabs_counter -= 1

          end

          current_block = convert_string_to_array(current_block, temporary_nila_file)

          nested_block = current_block.reject { |element| !element.include?("--block") }

          nested_block = nested_block.collect { |element| element.split("--block")[1] }

          nested_block = nested_block.collect { |element| element.rstrip.to_i }

          modified_nested_block = nested_block.clone

          current_block = current_block.join

          if !nested_block.empty?

            soft_tabs_counter += 1

          end

        end

        modified_blocks[x] = current_block

      end

      remaining_file_contents = ["(function() {\n", remaining_file_contents, "\n}).call(this);"].flatten

      joined_file_contents = remaining_file_contents.join

      main_blocks.each_with_index do |block_id, index|

        joined_file_contents = joined_file_contents.sub(block_id, modified_blocks[index])

      end

    else

      remaining_file_contents = remaining_file_contents.collect { |element| "  " + element }

      remaining_file_contents = ["(function() {\n", remaining_file_contents, "\n}).call(this);"].flatten

      joined_file_contents = remaining_file_contents.join

    end

    file_id = open(temporary_nila_file, 'w')

    file_id.write(joined_file_contents)

    file_id.close()

    line_by_line_contents = read_file_line_by_line(temporary_nila_file)

    line_by_line_contents = line_by_line_contents.collect {|element| element.gsub("%$%$ {","")}

    line_by_line_contents = fix_newlines(line_by_line_contents)

    removable_indices = line_by_line_contents.each_index.select {|index| line_by_line_contents[index].strip == "%$%$;" }

    while line_by_line_contents.join.include?("%$%$;")

      line_by_line_contents.delete_at(removable_indices[0])

      line_by_line_contents.delete_at(removable_indices[0])

      removable_indices = line_by_line_contents.each_index.select {|index| line_by_line_contents[index].strip == "%$%$;" }

    end

    line_by_line_contents = fix_syntax_indentation(line_by_line_contents)

    line_by_line_contents = line_by_line_contents.collect { |element| replace_ignored_words(element) }

    return line_by_line_contents

  end

  def compile_operators(input_file_contents)

    def compile_power_operator(input_string)

      matches = input_string.scan(/(\w{1,}\*\*\w{1,})/).to_a.flatten

      unless matches.empty?

        matches.each do |match|

          left, right = match.split("**")

          input_string = input_string.sub(match, "Math.pow(#{left},#{right})")

        end

      end

      return input_string

    end

    def compile_match_operator(input_string)

      rejection_exp = /( aannddy | orriioo |nnoottyy )/

      if input_string.include?("=~")

        input_string = input_string.gsub(" && "," aannddy ").gsub(" || "," orriioo ").gsub("!","nnoottyy")

        left, right = input_string.split("=~")

        if left.index(rejection_exp) != nil

          left = left[left.index(rejection_exp)..-1]

        elsif left.index(/\(/)

          left = left[left.index(/\(/)+1..-1]

        end

        if right.index(rejection_exp) != nil

          right = right[0...right.index(rejection_exp)]

        elsif right.index(/\)/)

          right = right[0...right.index(/\)/)]

        end

        original_string = "#{left}=~#{right}"

        replacement_string = "#{left.rstrip} = #{left.rstrip}.match(#{right.lstrip.rstrip})"

        input_string = input_string.sub(original_string,replacement_string)

        input_string = input_string.gsub(" aannddy "," && ").gsub(" orriioo "," || ").gsub("nnoottyy","!")

      end

      return input_string

    end

    input_file_contents = input_file_contents.collect { |element| element.sub("==", "===") }

    input_file_contents = input_file_contents.collect { |element| element.sub("!=", "!==") }

    input_file_contents = input_file_contents.collect { |element| element.sub("equequ", "==") }

    input_file_contents = input_file_contents.collect { |element| element.sub("elsuf", "else if") }

    input_file_contents = input_file_contents.collect { |element| compile_power_operator(element) }

    input_file_contents = input_file_contents.collect {|element| compile_match_operator(element)}

    input_file_contents = input_file_contents.collect {|element| element.gsub("_!;",";")}

    return input_file_contents

  end

  def pretty_print_nila(input_file_contents, temporary_nila_file)


  end

  def output_javascript(file_contents, output_file, temporary_nila_file)

    file_id = open(output_file, 'w')

    File.delete(temporary_nila_file)

    file_id.write("//Written using Nila. Visit http://adhithyan15.github.io/nila\n")

    file_id.write(file_contents.join)

    file_id.close()

  end

  if File.exist?(input_file_path)

    file_contents = read_file_line_by_line(input_file_path)

    file_contents = extract_parsable_file(file_contents)

    file_contents, multiline_comments, temp_file, output_js_file = replace_multiline_comments(file_contents, input_file_path, *output_file_name)

    file_contents, singleline_comments = replace_singleline_comments(file_contents)

    file_contents = split_semicolon_seperated_expressions(file_contents)

    file_contents = compile_heredocs(file_contents, temp_file)

    file_contents,loop_vars = compile_loops(file_contents,temp_file)

    file_contents = compile_interpolated_strings(file_contents)

    file_contents = compile_hashes(file_contents,temp_file)

    file_contents = compile_case_statement(file_contents,temp_file)

    file_contents = compile_conditional_structures(file_contents, temp_file)

    file_contents = compile_blocks(file_contents,temp_file)

    file_contents = compile_integers(file_contents)

    file_contents = compile_default_values(file_contents, temp_file)

    file_contents, named_functions, nested_functions = replace_named_functions(file_contents, temp_file)

    comments = [singleline_comments, multiline_comments]

    file_contents = compile_parallel_assignment(file_contents, temp_file)

    file_contents,named_functions = compile_arrays(file_contents, named_functions, temp_file)

    file_contents = compile_strings(file_contents)

    list_of_variables, file_contents = get_variables(file_contents, temp_file,loop_vars)

    file_contents, function_names = compile_named_functions(file_contents, named_functions, nested_functions, temp_file)

    func_names = function_names.dup

    file_contents, ruby_functions = compile_custom_function_map(file_contents)

    file_contents = compile_ruby_methods(file_contents)

    file_contents = compile_special_keywords(file_contents)

    function_names << ruby_functions

    list_of_variables += loop_vars

    file_contents = compile_whitespace_delimited_functions(file_contents, function_names, temp_file)

    file_contents = remove_question_marks(file_contents, list_of_variables, temp_file)

    file_contents = add_semicolons(file_contents)

    file_contents = compile_comments(file_contents, comments, temp_file)

    file_contents = pretty_print_javascript(file_contents, temp_file,list_of_variables+func_names)

    file_contents = compile_operators(file_contents)

    output_javascript(file_contents, output_js_file, temp_file)

    puts "Compilation is successful!"

  else

    puts "File doesn't exist!"

  end

end

def create_mac_executable(input_file)

  def read_file_line_by_line(input_path)

    file_id = open(input_path)

    file_line_by_line = file_id.readlines()

    file_id.close

    return file_line_by_line

  end

  mac_file_contents = ["#!/usr/bin/env ruby\n\n"] + read_file_line_by_line(input_file)

  mac_file_path = input_file.sub(".rb", "")

  file_id = open(mac_file_path, "w")

  file_id.write(mac_file_contents.join)

  file_id.close

end

def find_file_name(input_path, file_extension)

  extension_remover = input_path.split(file_extension)

  remaining_string = extension_remover[0].reverse

  path_finder = remaining_string.index("/")

  remaining_string = remaining_string.reverse

  return remaining_string[remaining_string.length-path_finder..-1]

end

def find_file_path(input_path, file_extension)

  extension_remover = input_path.split(file_extension)

  remaining_string = extension_remover[0].reverse

  path_finder = remaining_string.index("/")

  remaining_string = remaining_string.reverse

  return remaining_string[0...remaining_string.length-path_finder]

end
            
def parse_arguments(input_argv)
    
  argument_map = {
      
    %w{c compile} => "compile",
      
    %w{r run} => "run",
      
    %w{h help} => "help",
      
    %w{v version} => "version",
      
    %w{b build} => "build",
      
    %w{u update} => "update",
      
    %w{re release} => "release",
      
  }
    
  output_hash = {}

  argument_map.each do |key,val|
  
    if input_argv.include?("-#{key[0]}") or input_argv.include?("--#{key[1]}")
    
       output_hash[val.to_sym] = input_argv.reject {|element| element.include?("-#{key[0]}")} if input_argv.include?("-#{key[0]}")
            
       output_hash[val.to_sym] = input_argv.reject {|element| element.include?("--#{key[1]}")} if input_argv.include?("--#{key[1]}")
        
    else
        
       output_hash[val.to_sym] = nil
        
    end
      
  end

  return output_hash
    
end

nilac_version = "0.0.4.3.8"
            
opts =  parse_arguments(ARGV)
                
if opts[:build] != nil
                
  file_path = Dir.pwd + "/src/nilac.rb" 
  create_mac_executable(file_path)
  FileUtils.mv("#{file_path[0...-3]}", "#{Dir.pwd}/bin/nilac")
  puts "Build Successful!"

elsif opts[:compile] != nil

  if opts[:compile].length == 1
    
    input = opts[:compile][0]
      
    if input.include? ".nila"
      current_directory = Dir.pwd
      input_file = input
      file_path = current_directory + "/" + input_file
      compile(file_path)
    elsif input.include? "/"
      folder_path = input
      files = Dir.glob(File.join(folder_path, "*"))
      files = files.reject { |path| !path.include? ".nila" }
      files.each do |file|
        file_path = Dir.pwd + "/" + file
        compile(file_path)
      end
    end

  elsif opts[:compile].length == 2

    input = opts[:compile][0]
    output = opts[:compile][1]
      
    if input.include? ".nila" and output.include? ".js"
        
      input_file = input
      output_file = output
      input_file_path = input_file
      output_file_path = output_file
      compile(input_file_path, output_file_path)

    elsif input[-1].eql? "/" and output[-1].eql? "/"
        
      input_folder_path = input
      output_folder_path = output
        
      if !File.directory?(output_folder_path)
        FileUtils.mkdir_p(output_folder_path)
      end

      files = Dir.glob(File.join(input_folder_path, "*"))
      files = files.reject { |path| !path.include? ".nila" }
        
      files.each do |file|
        input_file_path = file
        output_file_path = output_folder_path + find_file_name(file, ".nila") + ".js"
        compile(input_file_path, output_file_path)
      end

    end

  end

elsif opts[:help] != nil
                
  puts "Nilac is the official compiler for the Nila language.This is a basic help\nmessage with pointers to more information.\n\n"
  puts "  Basic Usage:\n\n"
  puts "    nilac -h/--help\n"
  puts "    nilac -v/--version\n"
  puts "    nilac -u/--update => Update Checker\n"
  puts "    nilac [command] [file_options]\n\n"
  puts "  Available Commands:\n\n"
  puts "    nilac -c [nila_file] => Compile Nila File\n\n"
  puts "    nilac -c [nila_file]:[output_js_file] => Compile nila_file and saves it as\n    output_js_file\n\n"
  puts "    nilac -c [nila_file_folder] => Compiles each .nila file in the nila_folder\n\n"
  puts "    nilac -c [nila_file_folder]:[output_js_file_folder] => Compiles each .nila\n    file in the nila_folder and saves it in the output_js_file_folder\n\n"
  puts "    nilac -r [nila_file] => Compile and Run nila_file\n\n"
  puts "  Further Information:\n\n"
  puts "    Visit http://adhithyan15.github.io/nila to know more about the project.\n\n"
                
elsif opts[:run] != nil
                
  current_directory = Dir.pwd
  file = opts[:run][0]
  file_path = current_directory + "/" + file
  compile(file_path)
  js_file_name = find_file_path(file_path, ".nila") + find_file_name(file_path, ".nila") + ".js"
  node_output = `node #{js_file_name}`
  puts node_output

elsif opts[:release] != nil

  file_path = Dir.pwd + "/src/nilac.rb"
  create_mac_executable(file_path)
  FileUtils.mv("#{file_path[0...-3]}", "#{Dir.pwd}/bin/nilac")
  puts "Your build was successful!\n"
  commit_message = opts[:release][0]
  `git commit -am "#{commit_message}"`
  puts `rake release`
                
elsif opts[:update] != nil
                
  outdated_gems = `gem outdated`
  outdated_gems = outdated_gems.split("\n")
  outdated = false
  old_version = ""
  new_version = ""
                
  outdated_gems.each do |gem_name|
      
    if gem_name.include?("nilac")
      outdated = true
      old_version = gem_name.split("(")[1].split(")")[0].split("<")[0].lstrip
      new_version = gem_name.split("(")[1].split(")")[0].split("<")[1].lstrip.rstrip
      break
    end
      
  end

  if outdated
    exec = `gem update nilac`
    puts "Your version of Nilac (#{old_version}) was outdated! We have automatically updated you to the latest version (#{new_version})."
  else
    puts "Your version of Nilac is up to date!"
  end
                
elsif opts[:version] != nil
                
  puts nilac_version

end
