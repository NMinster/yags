class User < ActiveRecord::Base
  
  acts_as_login_model
  
  has_many :racks, :dependent => :destroy
  has_many :vials, :through => :racks
  has_many :character_preferences, :dependent => :destroy
  has_one  :basic_preference, :dependent => :destroy
  has_many :phenotype_alternates, :dependent => :destroy
  has_many :instructs, :class_name => "Course", :foreign_key => "instructor_id", :dependent => :destroy
  belongs_to :enrolled_in, :class_name => "Course", :foreign_key => "course_id"
  
  def solutions
    Solution.find_all_by_vial_id(vials.map { |v| v.id }, :order => "number")
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
    # this seems like not the best way to do
    visible_characters.include? character
  end
  
  def instructor?
    group.name == "instructor"
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
    if group.name == "admin" or self == other_user or students.include?(other_user)
      true
    else
      false
    end
  end
  
  # i wish we could generate these next two methods.  but i didn't know how
  def current_scenario
    if self.group.name == "student" and self.basic_preference
      Scenario.find_by_id basic_preference.scenario_id
      # change if a basic_preference belongs_to :senario relationship is set up
    else
      nil
    end
  end
  
  # hmm, the other method ^ doesn't have "_id" in it's name...
  def current_scenario_id=(new_id)
    if self.basic_preference
      if basic_preference.scenario_id != new_id
        basic_preference.scenario_id = new_id
        basic_preference.row, basic_preference.column = nil, nil
        basic_preference.save!
      end
    else
      self.basic_preference = BasicPreference.create!(:user_id => self.id, :scenario_id => new_id)
    end
  end
  
  def set_scenario_to(scenario_id, number_generator = RandomNumberGenerator.new)
    self.current_scenario_id = scenario_id
    if scenario_id and self.phenotype_alternates.select { |pa| pa.scenario_id == scenario_id }.size == 0
      Scenario.find(scenario_id).renamed_characters.map { |rc| rc.renamed_character }.each do |renamed_character|
        make_phenotype_alternates scenario_id, renamed_character, number_generator
      end
    end
  end
  
  def set_character_preferences(available_characters, chosen_characters)
    available_characters.each do |character|
      if chosen_characters.include?(character.to_s)
        CharacterPreference.find(:all, :conditions => 
            "user_id = #{self.id} AND hidden_character = \'#{character}\'").each { |p| p.destroy }
      else
        if !self.hidden_characters.include?(character)
          CharacterPreference.create!(:user_id => self.id, :hidden_character => character.to_s)
        end
      end
    end
    if self.basic_preference
      unless basic_preference.row && chosen_characters.include?(basic_preference.row) &&
          basic_preference.column && chosen_characters.include?(basic_preference.column)
        basic_preference.row, basic_preference.column = nil, nil
        basic_preference.save!
      end
    end
  end
  
  # helper
  
  def make_phenotype_alternates(scenario_id, renamed_character, number_generator)
    used_up_alternates = []
    current_scenario.species.phenotypes(renamed_character.intern).each do |phenotype|
      alternate_phenotypes = current_scenario.species.alternate_phenotypes(renamed_character.intern) - 
          used_up_alternates
      alternate_name = alternate_phenotypes[number_generator.random_number(alternate_phenotypes.size - 
          used_up_alternates.size)]
      phenotype_alternates << PhenotypeAlternate.create!( :user_id => self.id,
          :scenario_id => scenario_id, :affected_character => renamed_character,
          :original_phenotype => phenotype.to_s, :renamed_phenotype => alternate_name.to_s )
      used_up_alternates << alternate_name
    end
  end
  
end
