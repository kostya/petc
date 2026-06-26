record Myc::Location, filename : String, offset : UInt32 do
  protected def load_info : {Array(String), Int32, Int32}
    lines = File.read(filename).lines
    current_offset = 0
    line_number = 0

    lines.each_with_index do |line, idx|
      if current_offset + line.size > offset
        line_number = idx
        break
      end
      current_offset += line.size + 1
    end

    line_position = offset.to_i32 - current_offset
    {lines, line_number, line_position}
  end
end
