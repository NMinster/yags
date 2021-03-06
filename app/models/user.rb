class User < ActiveRecord::Base

  acts_as_login_model

  has_many :shelves, :dependent => :destroy
  has_many :vials, :through => :shelves
  has_many :character_preferences, :dependent => :destroy
  has_one  :basic_preference, :dependent => :destroy
  has_many :phenotype_alternates, :dependent => :destroy
  has_many :instructs, :class_name => "Course", :foreign_key => "instructor_id", :dependent => :destroy
  has_many :owned_scenarios, :class_name => 'Scenario', :foreign_key => :owner_id, :dependent => :destroy
  belongs_to :enrolled_in, :class_name => "Course", :foreign_key => "course_id"

  def self.batch_create!(csv, password, course)
    number_added = 0
    FasterCSV.parse(csv.strip) do |row|
      student = User.new
      student.enrolled_in = course
      row.each { |e| e.strip! if e }
      student.last_name     = row.shift
      student.first_name    = row.shift
      student.email_address = row.shift
      student.username      = student.email_address.split('@').first
      student.group         = Group.find_by_name "student"
      student.password      = password
      student.password_confirmation = password
      student.save
      number_added += 1 if student.save!
    end
    number_added
  end

  def solutions
    vials.map { |vial| vial.solution }.compact.sort_by { |solution| solution.number }
  end

  def solutions_as_hash
    answer = Hash.new
    solutions.each do |solution|
      answer[solution.number] = solution
    end
    answer
  end

  def hidden_characters
    if self.current_scenario
      character_preferences.map { |p| p.hidden_character.intern } + current_scenario.hidden_characters
    else
      character_preferences.map { |p| p.hidden_character.intern }
    end
  end

  def visible_characters(characters = Species.singleton.characters)
    characters - hidden_characters
  end

  def visible?(character)
    visible_characters.include? character
  end

  def student?
    group.name == "student"
  end

  def instructor?
    group.name == "instructor"
  end

  def admin?
    group.name == "admin"
  end

  def owns?(object)
    self == object.owner
  end

  def students
    if instructor?
      instructs.map { |c| c.students }.flatten
    else
      []
    end
  end

  def has_authority_over(other_user)
    group.name == "admin" || self == other_user || students.include?(other_user)
  end

  def current_shelves
    must_have_current_scenario
    self.shelves.find(:all, :conditions => ["scenario_id = ?", current_scenario.id])
  end

  def current_shelves_without_trash
    current_shelves - [trash_shelf]
  end

  def trash_shelf
    trash = current_shelves.select { |r| r.trash? }.first
    if trash.nil?
      self.add_default_shelves_for_current_scenario
      trash = current_shelves.select { |r| r.trash? }.first
    end
    trash
  end

  def current_vials
    must_have_current_scenario
    self.shelves.find(:all, :conditions => ["scenario_id = ?", current_scenario.id]).map(&:vials).flatten
  end

  def add_default_shelves_for_current_scenario
    if current_shelves.empty?
      add_shelf_with_current_scenario("Default")
    end
    add_shelf_with_current_scenario("Trash")
  end

  def row
    basic_preference.row
  end

  def column
    basic_preference.column
  end

  def current_scenario
    if self.group.name == "student" && self.basic_preference
      basic_preference.scenario
    else
      nil
    end
  end

  def current_scenario_id=(new_id)
    if self.basic_preference
      if basic_preference.scenario_id != new_id
        basic_preference.scenario_id = new_id
        basic_preference.row, basic_preference.column = nil, nil
        basic_preference.save!
      end
    else
      self.create_basic_preference(:user_id => self.id, :scenario_id => new_id)
    end
  end

  def set_scenario_to(scenario_id, number_generator = RandomNumberGenerator.new)
    if enrolled_in.scenario_ids.include? scenario_id
      self.current_scenario_id = scenario_id
      self.reload
      self.add_default_shelves_for_current_scenario
      if scenario_id and self.phenotype_alternates.select { |pa| pa.scenario_id == scenario_id }.size == 0
        Scenario.find(scenario_id).renamed_characters.map { |rc| rc.renamed_character }.each do |renamed_character|
          make_phenotype_alternates scenario_id, renamed_character, number_generator
        end
      end
    end
  end

  def set_table_preference(row, column)
    must_have_current_scenario
    basic_preference.row, basic_preference.column = row, column
    basic_preference.save!
  end

  def set_character_preferences(available_characters, chosen_characters)
    available_characters.each do |character|
      if chosen_characters.include?(character.to_s)
        CharacterPreference.destroy_all(
                ["user_id = :user_id AND hidden_character = :character",
                 { :user_id => self.id, :character => character.to_s }])
      else
        if !self.hidden_characters.include?(character)
          CharacterPreference.create!(:user_id => self.id, :hidden_character => character.to_s)
        end
      end
    end
    unless row && chosen_characters.include?(row) &&
            column && chosen_characters.include?(column)
      set_table_preference nil, nil
    end
  end

  # helper

  def make_phenotype_alternates(scenario_id, renamed_character, number_generator)
    used_alternates = []
    current_scenario.species.phenotypes(renamed_character.intern).each do |phenotype|
      alternate_phenotypes = current_scenario.species.alternate_phenotypes(renamed_character.intern) -
              used_alternates
      alternate_name = alternate_phenotypes[number_generator.random_number(alternate_phenotypes.size -
              used_alternates.size)]
      phenotype_alternates.create!( :user_id => self.id,
                                    :scenario_id => scenario_id, :affected_character => renamed_character,
                                    :original_phenotype => phenotype.to_s, :renamed_phenotype => alternate_name.to_s )
      used_alternates << alternate_name
    end
  end

  private

  def must_have_current_scenario
    raise Exception.new("must have a current scenario") unless current_scenario
  end

  def add_shelf_with_current_scenario(label)
    if !current_shelves.detect{ |r| r.label == label }
      shelf = self.shelves.build(:label => label)
      shelf.scenario = current_scenario
      shelf.save!
    end
  end

end
