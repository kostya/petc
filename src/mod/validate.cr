struct Myc::Mod::Validate
  def initialize(@mod : Mod)
  end

  def validate!
    check_recursion
  end

  private def check_recursion
    @mod.type_defs.each do |name, type_def|
      check_type_recursion(type_def, type_def.type, Set(String).new, [name])
    end
  end

  private def check_type_recursion(type_def : Mod::TypeDef, type : Type, in_chain : Set(String), path : Array(String))
    case type
    when Type::StructType
      if in_chain.includes?(type.id_name)
        cycle = path[path.index(type.id_name)..] + [type.id_name]
        raise error("struct cycle detected: #{cycle.join(" > ")} (use ptr<...> to break recursion)", type_def.node)
      end

      in_chain << type.id_name
      path << type.id_name

      type.data.each do |field|
        check_type_recursion(type_def, field, in_chain, path)
      end

      in_chain.delete(type.id_name)
      path.pop
    when Type::FlatType
      check_type_recursion(type_def, type.target_type, in_chain, path)
    when Type::EnumType
      if in_chain.includes?(type.id_name)
        cycle = path[path.index(type.id_name)..] + [type.id_name]
        raise error("enum cycle detected: #{cycle.join(" > ")}", type_def.node)
      end

      in_chain << type.id_name
      path << type.id_name

      type.data.each do |_, variant_type|
        check_type_recursion(type_def, variant_type, in_chain, path) if variant_type
      end

      in_chain.delete(type.id_name)
      path.pop
    when Type::PtrType
    end
  end

  private def error(msg, node)
    node.error(msg, @mod.filename)
  end
end
