require "erb"
include ERB::Util

class BenchController < ApplicationController
  in_place_edit_for :vial, :label
  in_place_edit_for :shelf, :label
  restrict_to :manage_bench
  before_filter :redirect_students_without_scenarios, :except => "choose_scenario"
  
  def index; end
  
  def preferences
    @user = current_user
    if current_user.current_scenario
      @characters = current_user.current_scenario.visible_characters
    else
      @characters = Species.singleton.characters # or [] ?
    end
    if request.post?
      current_user.set_character_preferences(@characters, params[:characters])
      redirect_to :action => "index"
    end
  end
  
  def choose_scenario
    if current_user.current_scenario
      @current_scenario_title = current_user.current_scenario.title
    else
      @current_scenario_title = "None Selected"
    end
    if request.post?
      current_user.set_scenario_to params[:basic_preference][:scenario_id].to_i
      redirect_to :action => "index"
    end
  end
  
  def collect_field_vial
    @flies_number = current_user.basic_preference.flies_number
    if request.post? && params[:vial] && current_user.owns?(Shelf.find_by_id(params[:vial][:shelf_id]))
      @vial = Vial.collect_from_field(params[:vial])
      @vial.save!
      current_user.basic_preference.flies_number = @vial.number_of_requested_flies
      current_user.basic_preference.save!
      redirect_to :action => "view_vial", :id => @vial.id
    else
      render
    end
  rescue ActiveRecord::RecordInvalid
    render
  end
  
  def mate_flies
    if request.get? && !request.xhr?
      @flies_number = current_user.basic_preference.flies_number
      render
    else
      must_use_xhr_post
      @vial = Vial.make_babies_and_vial(params[:vial].merge({ :creator => current_user }))
      @vial.save!
      current_user.basic_preference.flies_number = @vial.number_of_requested_flies
      current_user.basic_preference.save!
      render :update do |page|
        page.redirect_to :action => "view_vial", :id => @vial.id
      end
    end
  rescue InvalidHttpMethod, InvalidOwner
    render :nothing => true, :status => 401
  rescue ActiveRecord::RecordInvalid
    render :update do |page|
      page.replace_html :errors, :inline => "<%= error_messages_for 'vial' %>"
      page.visual_effect :fade, "spinner_cross"
      page['cross_button'].disabled = false
    end
  end
  
  def show_mateable_flies
    must_use_xhr_post
    @which_vial = params[:which_vial]
    if params[:vial_id].to_i.zero?
      render :partial => 'redisplay_vial_selector_instructions'
    else
      @vial = Vial.find(params[:vial_id].to_i, :include => [ { :shelf => :owner }, { :flies => :genotypes } ])
      current_user_must_own @vial
      @phenotypes_to_flies = phenotypes_to_flies(@vial, current_user.visible_characters)
      render
    end
  rescue InvalidHttpMethod, InvalidOwner
    render :nothing => true, :status => 401
  end
  
  def update_parent_div
    must_use_xhr_post
    @fly = Fly.find(params[:id])
    current_user_must_own(@fly)
    @sex = params[:sex]
    render
  rescue InvalidHttpMethod, InvalidOwner
    render :nothing => true, :status => 401
  rescue # fly not found
    render :nothing => true, :status => 401
  end
  
  def view_vial
    if valid_vial_to_view?
      @vial = Vial.find_by_id(params[:id])
      @visible_characters = current_user.visible_characters
      @table = current_user.row && current_user.column
      if @table
        @row_character = current_user.row.intern
        @column_character = current_user.column.intern
        @row_phenotypes = @vial.phenotypes_for_table(@row_character)
        @column_phenotypes = @vial.phenotypes_for_table(@column_character)
        @counts = @vial.counts_for_table(@row_character, @column_character)
      end
    else
      redirect_to :action => "list_vials"
    end
  end
  
  def list_vials
    @shelves = current_user.current_shelves_without_trash
    @trash = current_user.trash_shelf
  end
  
  def destroy_vial
    if request.post?
      @vial = Vial.find(params[:vial_id])    
      if current_user.owns?(@vial) && @vial.solution == nil
        @vial.shelf = current_user.trash_shelf
        @vial.save!
      elsif @vial.solution && @vial.solution.number != nil
        flash[:notice] = "#{@vial.label} cannot be moved to the Trash because it is a solution to problem #{@vial.solution.number}."
      end
      redirect_to :action => "list_vials"
    end
  end
  
  def set_vial_label
    must_use_xhr_post
    @vial = Vial.find(params[:id])
    if current_user.owns?(@vial)
      previous_label = @vial.label
      @vial.label = params[:value]
      @vial.label = previous_label unless @vial.save
      render :text => h(@vial.label)
    else
      raise InvalidOwner
    end
  rescue InvalidHttpMethod, InvalidOwner
    render :nothing => true, :status => 401
  end
  
  def set_shelf_label
    must_use_xhr_post
    @shelf = Shelf.find(params[:id])
    if current_user.owns?(@shelf)
      previous_label = @shelf.label
      # Should we use a regex instead of 'Trash'?
      @shelf.label = params[:value] if params[:value] != "Trash"
      @shelf.label = previous_label unless @shelf.save
      render :text => h(@shelf.label)
    else
      raise InvalidOwner
    end
  rescue InvalidHttpMethod, InvalidOwner
    render :nothing => true, :status => 401
  end
  
  def set_as_solution
    if request.post?
      @old_solution = find_old_solution(params[:solution])
      if @old_solution
        @old_solution.update_attributes(params[:solution])
      else
        @solution = Solution.new params[:solution]
        @solution.save!
      end
      render
    else
      render :nothing => true
    end
  rescue ActiveRecord::RecordInvalid
    render
  end
  
  def update_table
    must_use_xhr_post
    @vial = Vial.find(params[:vial_id])
    if current_user.owns?(@vial)
      @column_character = params[:character_col].intern
      @row_character = params[:character_row].intern
      @column_phenotypes = @vial.phenotypes_for_table(@column_character)
      @row_phenotypes = @vial.phenotypes_for_table(@row_character)
      @counts = @vial.counts_for_table(@row_character, @column_character)
      current_user.set_table_preference @row_character.to_s, @column_character.to_s
    else
      raise InvalidOwner
    end
  rescue InvalidHttpMethod, InvalidOwner
    render :nothing => true, :status => 401
  end
  
  def add_shelf
    if params[:shelf]
      @shelf = Shelf.new params[:shelf]
      @shelf.owner = current_user
      @shelf.scenario = current_user.current_scenario
      @shelf.save! unless @shelf.trash?
      redirect_to :action => "list_vials"
    else
      render
    end
    rescue ActiveRecord::RecordInvalid
    render
  end
  
  def move_vial_to_another_shelf
    if request.post?
      @vial = Vial.find(params[:id])
      @shelf = Shelf.find(params[:vial][:shelf_id])
      if current_user.owns?(@vial) and current_user.owns?(@shelf)
        @vial.shelf = @shelf
        @vial.save!
        render :update do |page|
          page.replace_html 'move_notice', :partial => 'move_vial_notice'
        end
      else
        # flash[:notice] = "Action failed - bad parameters" # or something
        redirect_to :action => "list_vials"
      end
    else
      render :nothing => true
    end
  end

  #
  # Helpers
  #
  private

    def find_old_solution(options)
      number = options[:number].to_i
      vial_id = options[:vial_id].to_i
      old_solution = current_user.solutions.find do |solution|
        solution.number == number || solution.vial_id == vial_id
      end
    end
    
    def valid_vial_to_view?
      params[:id] && Vial.find_by_id(params[:id]) && current_user.owns?(Vial.find(params[:id]))
    end
    
    def redirect_students_without_scenarios
      unless current_user.current_scenario
        redirect_to :action => "choose_scenario"
        # flash[:notice] = "Please choose a scenario"
      end
    end
  
    def phenotypes_to_flies(vial, visible_characters)
      flies = {}
      vial.combinations_of_phenotypes(visible_characters).each do |combination|
        flies[combination] = vial.flies_of_type(visible_characters, combination)
      end
      flies
    end
    
end
