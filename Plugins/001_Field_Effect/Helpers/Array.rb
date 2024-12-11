class Array
  alias random sample

  alias choose values_at

  def number?
    all? { |element| element.is_a?(Numeric) }
  end

  def nested?
    any? { |element| element.is_a?(Array) }
  end

  def pure?
    none? { |element| element.is_a?(Array) }
  end

  def dup?
    length != uniq.length
  end

  def add(*elements, ignore: true)
    elements.flatten!
    if ignore
      concat(elements)
    else
      elements.each { |element| self << element if !has?(element) }
    end
    self
  end

  def add_to_start(*elements, ignore: true)
    elements.flatten!
    if ignore
      elements.reverse_each { |element| unshift(element) }
    else
      elements.reverse_each { |element| unshift(element) if !has?(element) }
    end
    self
  end

  def swap(index_1, index_2)
    new_array = dup
    new_array[index_1], new_array[index_2] = new_array[index_2], new_array[index_1]
    new_array
  end

  def swap!(index_1, index_2)
    self[index_1], self[index_2] = self[index_2], self[index_1]
    self
  end

  def move_to(index, new_index)
    return self if index < 0 || index >= length || new_index < 0
    element = self[index]
    delete_at(index)
    insert(new_index, element)
  end

  def move_to_start(index)
    return self if index < 0 || index > length
    element = self[index]
    delete_at(index)
    unshift(element)
  end

  def move_to_end(index)
    return self if index < 0 || index > length
    element = self[index]
    delete_at(index)
    add(element)
  end

  def quick_join(joiner = ", ", ender = " and ")
    length <= 1 ? join(joiner) : "#{self[0..-2].join(joiner)}#{ender}#{self[-1]}"
  end

  def mid(mode: :random)
    mid_index = (size - 1) / 2.0
    if size.odd?
      self[mid_index.to_i]
    else
      case mode
      when :random
        mid_index = [mid_index.floor, mid_index.ceil].sample
        self[mid_index]
      when :small
        self[mid_index.floor]
      when :large
        self[mid_index.ceil]
      end
    end
  end

  def average
    array = compact
    array.sum / array.size.to_f
  end

  def elements_count
    each_with_object(Hash.new(0)) { |element, counts| counts[element] += 1 }
  end

  def most_elements
    elements_count.select { |_element, count| count == most_elements_count }.keys
  end

  def most_element
    most_elements.sample
  end

  def most_elements_count
    elements_count.values.max
  end

  def least_elements
    elements_count.select { |_element, count| count == least_elements_count }.keys
  end

  def least_element
    least_elements.sample
  end

  def least_elements_count
    elements_count.values.min
  end

  def map_to(type, flatten = false)
    if flatten
      flatten.map! { |element| element.send(type) }
    else
      map do |element|
        element.is_a?(Array) ? element : element.send(type)
      end
    end
  end

  def map_to_sym(flatten = false)
    if flatten
      flatten.map!(&:to_sym)
    else
      map do |element|
        element.is_a?(Array) ? element : element.to_sym
      end
    end
  end

  def map_to_s(flatten = false)
    if flatten
      flatten.map!(&:to_s)
    else
      map do |element|
        element.is_a?(Array) ? element : element.to_s
      end
    end
  end

  def map_to_i(flatten = false)
    if flatten
      flatten.map!(&:to_i)
    else
      map do |element|
        element.is_a?(Array) ? element : element.to_i
      end
    end
  end

  def map_to_f(flatten = false)
    if flatten
      flatten.map!(&:to_f)
    else
      map do |element|
        element.is_a?(Array) ? element : element.to_f
      end
    end
  end
end