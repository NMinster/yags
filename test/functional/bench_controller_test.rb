require File.dirname(__FILE__) + '/../test_helper'
require 'bench_controller'

# Re-raise errors caught by the controller.
class BenchController; def rescue_action(e) raise e end; end

class BenchControllerTest < Test::Unit::TestCase
  all_fixtures
  
  def setup
    @controller = BenchController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  
  def test_collect_field_vial_of_four_flies
    number_of_old_vials =  Vial.count
    
    post :collect_field_vial, {
      :vial => {
        :label => "four fly vial",
        :number_of_requested_flies => "4" }
    },
    user_session(:steve)
    
    new_vial = Vial.find_by_label("four fly vial")
    assert_not_nil new_vial
    assert_equal number_of_old_vials + 1, Vial.find(:all).size
    assert_equal 4, new_vial.flies.size
    assert_equal users(:steve), new_vial.owner
    assert_response :redirect
    assert_redirected_to :action => "view_vial", :id => new_vial.id
  end
  
  def test_collect_field_vial_of_nine_flies
    number_of_old_vials =  Vial.count
    
    post :collect_field_vial, {
      :vial => {
        :label => "nine fly vial",
        :number_of_requested_flies => "9"
      } },
    user_session(:steve)
    
    assert logged_in?, "should be logged in"
    new_vial = Vial.find_by_label("nine fly vial")
    assert_not_nil new_vial
    assert_equal number_of_old_vials + 1, Vial.count
    assert_equal 9, new_vial.flies.size
    assert_equal users(:steve), new_vial.owner
    assert_response :redirect
    assert_redirected_to :action => "view_vial", :id => new_vial.id
  end
  
  def test_collect_field_vial_fails_when_NOT_logged_in
    assert_no_added_vials do
      post :collect_field_vial, {
          :vial => {
            :label => "anonomous user's vial",
            :number_of_requested_flies => "8" } }
      assert_redirected_to_login
    end
  end
  
  def test_collect_field_vial_fails_if_number_invalid
    assert_no_added_vials do
      post :collect_field_vial, {
        :vial => {
          :label => "some vial",
          :number_of_requested_flies => "581" }
      },
      user_session(:steve)
      
      vial = assigns(:vial)
      assert vial.errors.invalid?(:number_of_requested_flies)
    end
  end
  
  def test_collect_field_vial_page
    post :collect_field_vial, {}, user_session(:steve)
    assert_response :success
    assert_standard_layout
    
    assert_select "form" do
      assert_select "label", "Label:"
      assert_select "input#vial_label"
      assert_select "label", "Number of flies:"
      assert_select "input#vial_number_of_requested_flies"
    end
  end
  
  def test_add_rack
    number_of_old_racks =  Rack.find(:all).size
    post :add_rack, {
        :rack => { :label => "super storage unit"} },
        user_session(:steve)
        
    new_rack = Rack.find_by_label("super storage unit")
    assert_not_nil new_rack
    assert_equal number_of_old_racks + 1, Rack.find(:all).size
    assert_equal users(:steve), new_rack.owner
    assert_response :redirect
    assert_redirected_to :action => "list_vials"
  end
  
  def test_add_rack_fails_when_NOT_logged_in
    post :add_rack, { :rack => { :label => "super duper unit"} }
    assert_redirected_to_login
  end
  
  def test_add_rack_page
    get :add_rack, {}, user_session(:steve)
    
    assert_response :success
    assert_standard_layout
    
    assert_select "form" do
      assert_select "label", "Label:"
      # TODO: this next assertion is useless because it finds the same label as the previous line
      assert_select "label"
      # TODO: assert the input field(s)
    end
  end
  
  def test_move_vial_to_another_rack_page
    get :move_vial_to_another_rack, { :id => 5 }, user_session(:steve)
    assert_response :success
    assert_standard_layout
    
    assert_select "form" do
      assert_select "select#rack_id" do
        assert_select "option", 2
      end
    end
  end
  
  def test_move_vial_to_another_rack
    number_of_old_vials_in_rack = Rack.find(1).vials.size
    post :move_vial_to_another_rack, { :id => 5, :rack_id => 1 }, user_session(:steve)
    assert_equal number_of_old_vials_in_rack + 1, Rack.find(1).vials.size
    assert_equal 1, Vial.find(5).rack_id
    assert_response :redirect
    assert_redirected_to :action => "view_vial", :id => 5
  end
  
  def test_move_vial_to_another_rack_fails_when_NOT_logged_in
    post :move_vial_to_another_rack, { :id => 4, :rack_id => 1 }
    assert_redirected_to_login
  end
  
  def test_move_vial_to_another_rack_fails_when_NOT_owner_of_vial
    post :move_vial_to_another_rack, { :id => 7, :rack_id => 1 }, user_session(:steve)
    assert_redirected_to :action => "list_vials"
  end
  
  def test_move_vial_to_another_rack_fails_when_NOT_owner_of_rack
    post :move_vial_to_another_rack, { :id => 3, :rack_id => 5 }, user_session(:steve)
    assert_redirected_to :action => "list_vials"
  end
  
  def test_view_vial_with_a_fly
    vial = vials(:vial_with_a_fly)
    
    get :view_vial, { :id => vial.id }, user_session(:steve)
    
    assert_response :success
    assert_standard_layout
    
    assert_select "h1", /Vial #{vial.label}/
    assert_select "span#vial_label_3_in_place_editor", vial.label
    
    assert_select "div#solution_notice", ""
    assert_select "div#vial-table" do
      assert_select "img[src^=/images/blank_table.png]"
    end
    
    assert_select "form[action=/bench/update_table]" do
      assert_select "select[name=character_col]" do
        assert_select "option[value=sex]", "sex"
        assert_select "option[value=eye color]", "eye color"
        assert_select "option[value=wings]", "wings"
        assert_select "option[value=legs]", "legs"
        assert_select "option[value=antenna]", "antenna"
      end
      assert_select "select[name=character_row]" do
        assert_select "option[value=sex]", "sex"
        assert_select "option[value=eye color]", "eye color"
        assert_select "option[value=wings]", "wings"
        assert_select "option[value=legs]", "legs"
        assert_select "option[value=antenna]", "antenna"
      end
    end
    
    assert_select "div#parent-info table" do
      assert_select "p", "Parent information is unknown for field vials."
    end
    assert_select "div#vial_maintenance" do
      assert_select "form[action=/bench/set_as_solution]" do 
        assert_select "label", "Submit as a solution to Problem #"
        assert_select "select#solution_number" do
          assert_select "option[value=]", ""
          assert_select "option[value=1]", "1"
          assert_select "option[value=2]", "2"
          assert_select "option[value=3]", "3"
          assert_select "option[value=4]", "4"
          assert_select "option[value=5]", "5"
          assert_select "option[value=6]", "6"
          assert_select "option[value=7]", "7"
          assert_select "option[value=8]", "8"
          assert_select "option[value=9]", "9"
        end
        assert_select "input[type=hidden][value=3]"
      end
    end
  end
  
  def test_view_vial_with_many_flies
    vial = vials(:vial_with_many_flies)
    
    get :view_vial, { :id => vial.id }, user_session(:steve)
    
    assert_response :success
    assert_standard_layout
    
    assert_select "h1", /Vial #{vial.label}/
    assert_select "span#vial_label_4_in_place_editor", vial.label
    
    assert_select "div#solution_notice", ""
    
    assert_select "div#vial-table" do
      assert_select "img[src^=/images/blank_table.png]"
    end
    
    assert_select "form[action=/bench/update_table]" do
      assert_select "select[name=character_col]" do
        assert_select "option[value=sex]", "sex"
        assert_select "option[value=eye color]", "eye color"
        assert_select "option[value=wings]", "wings"
        assert_select "option[value=legs]", "legs"
        assert_select "option[value=antenna]", "antenna"
      end
      assert_select "select[name=character_row]" do
        assert_select "option[value=sex]", "sex"
        assert_select "option[value=eye color]", "eye color"
        assert_select "option[value=wings]", "wings"
        assert_select "option[value=legs]", "legs"
        assert_select "option[value=antenna]", "antenna"
      end
    end
    
    assert_select "div#parent-info table" do
      assert_select "p", "Parent information is unknown for field vials."
    end
    assert_select "div#vial_maintenance" do
      assert_select "form[action=/bench/set_as_solution]" do 
        assert_select "label", "Submit as a solution to Problem #"
        assert_select "select#solution_number" do
          assert_select "option[value=]", ""
          assert_select "option[value=1]", "1"
          assert_select "option[value=2]", "2"
          assert_select "option[value=3]", "3"
          assert_select "option[value=4]", "4"
          assert_select "option[value=5]", "5"
          assert_select "option[value=6]", "6"
          assert_select "option[value=7]", "7"
          assert_select "option[value=8]", "8"
          assert_select "option[value=9]", "9"
        end
        assert_select "input[type=hidden][value=4]"
      end
    end
  end
  
  def test_view_vial_one
    vial = vials(:vial_one)
    
    get :view_vial, { :id => vial.id }, user_session(:steve)
    
    assert_response :success
    assert_standard_layout
    
    assert_select "h1", /Vial #{vial.label}/
    assert_select "span#vial_label_1_in_place_editor", vial.label    
    assert_select "div#solution_notice", "This is a solution to Problem #8."
    assert_select "div#vial-table" do
      assert_select "img[src^=/images/blank_table.png]"
    end
    
    assert_select "form[action=/bench/update_table]" do
      assert_select "select[name=character_col]" do
        assert_select "option[value=sex]", "sex"
        assert_select "option[value=eye color]", "eye color"
        assert_select "option[value=wings]", "wings"
        assert_select "option[value=legs]", "legs"
        assert_select "option[value=antenna]", "antenna"
      end
      assert_select "select[name=character_row]" do
        assert_select "option[value=sex]", "sex"
        assert_select "option[value=eye color]", "eye color"
        assert_select "option[value=wings]", "wings"
        assert_select "option[value=legs]", "legs"
        assert_select "option[value=antenna]", "antenna"
      end
    end
    
    assert_select "div#parent-info table" do
      assert_select "p", "Parent information is unknown for field vials."
    end
    assert_select "div#vial_maintenance" do
      assert_select "form[action=/bench/set_as_solution]" do 
        assert_select "label", "Submit as a solution to Problem #"
        assert_select "select#solution_number" do
          assert_select "option[value=]", ""
          assert_select "option[value=1]", "1"
          assert_select "option[value=2]", "2"
          assert_select "option[value=3]", "3"
          assert_select "option[value=4]", "4"
          assert_select "option[value=5]", "5"
          assert_select "option[value=6]", "6"
          assert_select "option[value=7]", "7"
          assert_select "option[value=8][selected=selected]", "8"
          assert_select "option[value=9]", "9"
        end
        assert_select "input[type=hidden][value=1]"
      end
    end
  end
  
  def test_view_vial_fails_when_NOT_logged_in
    get :view_vial, { :id => vials(:vial_one).id }
    assert_redirected_to_login
  end
  
  def test_view_vial_fails_when_NOT_users_vial
    get :view_vial, { :id => vials(:vial_one).id }, user_session(:jeremy)
    assert_redirected_to :action => "list_vials"
    
    get :view_vial, { :id => 123123 }, user_session(:steve)
    assert_redirected_to :action => "list_vials"
  end
  
  def test_steve_has_no_table_preference
    get :view_vial, { :id => vials(:vial_one).id }, user_session(:steve)
    assert_response :success
    assert_select "img[src^=/images/blank_table.png]", true, "should have displayed an example image"
  end
  
  def test_jeremy_has_table_preferences
    get :view_vial, { :id => vials(:random_vial).id }, user_session(:jeremy)
    assert_response :success
    assert_select "table" do
      assert_select "tr:nth-child(1) th:nth-child(2)", "beige"
      assert_select "tr:nth-child(1) th:nth-child(3)", "orange"
      assert_select "tr:nth-child(2) th:nth-child(1)", "curly"
      assert_select "tr:nth-child(3) th:nth-child(1)", "straight"
    end
  end
  
  def test_visible_characters_in_select_boxes_for_table
    get :view_vial, {:id => vials(:random_vial).id }, user_session(:jeremy)
    assert_response :success
    assert_select "select[name=character_col]" do
      assert_select "option[value=sex]"
      assert_select "option[value=eye color]"
      assert_select "option[value=wings]"
    end
    assert_select "select[name=character_row]" do
      assert_select "option[value=sex]"
      assert_select "option[value=eye color]"
      assert_select "option[value=wings]"
    end
  end
  
  def test_set_vial_label
    xhr :post, :set_vial_label, { :id => vials(:vial_one).id, :value => '<Bob>' }, user_session(:steve)
    
    assert_response :success
    assert_equal '&lt;Bob&gt;', @response.body
    
    vial = vials(:vial_one)
    vial.reload
    assert_equal '<Bob>', vial.label
  end
  
  def test_set_vial_label_fails_when_NOT_logged_in
    get :set_vial_label, { :id => vials(:vial_one).id, :value => 'Cool!!!!' }
    assert_redirected_to_login
  end
  
  def test_set_rack_label
    xhr :post, :set_rack_label, { :id => racks(:steve_bench_rack).id, :value => 'Stock > Bench'}, user_session(:steve)
    
    assert_response :success
    assert_equal 'Stock &gt; Bench', @response.body
    
    rack = racks(:steve_bench_rack)
    rack.reload
    assert_equal 'Stock > Bench', rack.label
  end
  
  def test_set_rack_label_fails_when_NOT_logged_in
    get :set_rack_label, { :id => racks(:steve_stock_rack).id, :value => 'I am not logged in!' }
    assert_redirected_to_login
  end
  
  def test_set_as_solution
    vial = vials(:vial_with_many_flies)
    
    xhr :post, :set_as_solution, { :solution => { :number => 1, :vial_id => vial.id } }, user_session(:steve)
    assert_response :success
    
    vial.reload
    assert_not_nil vial.solution
    assert_equal 1, vial.solution.number
    
    assert_select_rjs "solution_notice", "img[src=/images/star.png]"
    assert_select_rjs "solution_notice", "This vial is now a solution for problem 1."
  end
  
  def test_set_as_solution_resets_problem_of_vial
    vial = vials(:random_vial)
    original_2_count = Solution.find_all_by_number(2).size
    original_9_count = Solution.find_all_by_number(9).size
    
    xhr :post, :set_as_solution, { :solution => { :number => 9, :vial_id => vial.id } }, user_session(:jeremy)
    assert_response :success
    
    vial.reload
    assert_not_nil vial.solution
    assert_equal 9, vial.solution.number
    assert_equal original_2_count - 1, Solution.find_all_by_number(2).size
    assert_equal original_9_count + 1, Solution.find_all_by_number(9).size
    
    assert_select_rjs "solution_notice", "img[src=/images/star.png]"
    assert_select_rjs "solution_notice", "This vial is now a solution for problem 9."
  end
  
  def test_set_as_solution_replacement_vial_for_problem_which_already_has_a_solution
    original_vial = vials(:random_vial)
    replacement_vial = vials(:destroyable_vial)
    assert_not_nil original_vial.solution
    assert_nil replacement_vial.solution
    
    xhr :post, :set_as_solution, { :solution => { :number => 2, :vial_id => replacement_vial.id } }, user_session(:jeremy)
    assert_response :success
    
    original_vial.reload
    replacement_vial.reload
    assert_nil original_vial.solution
    assert_not_nil replacement_vial.solution
    assert_equal 2, replacement_vial.solution.number
    
    assert_select_rjs "solution_notice", "img[src=/images/star.png]"
    assert_select_rjs "solution_notice", "This vial is now a solution for problem 2."
  end
  
  def test_set_as_solution_fails_when_NOT_logged_in
    xhr :post, :set_as_solution, {:number => 1, :vial_id => vials(:vial_with_many_flies).id }
    assert_redirected_to_login
  end
  
  def test_update_table
    xhr :post, :update_table, { :vial_id => vials(:vial_one).id, :character_col => "eye color", 
      :character_row => "sex" }, user_session(:steve)
    assert_response :success
    
    assert_select "table" do
      assert_select "tr:nth-child(1) th:nth-child(2)", "red"
      assert_select "tr:nth-child(1) th:nth-child(3)", "white"
      assert_select "tr:nth-child(2) th:nth-child(1)", "female"
      assert_select "tr:nth-child(3) th:nth-child(1)", "male"
    end
  end
  
  def test_update_table_fails_when_NOT_logged_in
    xhr :post, :update_table,
        { :vial_id => vials(:vial_one).id, :character_col => "legs",
          :character_row => "wings" }
    assert_redirected_to_login
  end
  
  def test_update_parent_div
    xhr :post, :update_parent_div,
        {:id => flies(:fly_dad).id, :sex => "dad" },
        user_session(:steve)
    assert_response :success
    
    assert_select "input[type=hidden][value=7]"
    
    xhr :post, :update_parent_div,
        {:id => flies(:fly_mom).id, :sex => "mom" },
        user_session(:steve)
    assert_response :success
    
    assert_select "input[type=hidden][value=6]"
  end
  
  def test_update_parent_div_fails_when_NOT_logged_in
    xhr :post, :update_parent_div, {:id => flies(:fly_mom).id, :sex => "mom" }
    assert_redirected_to_login
  end
  
  def test_delete_vial
    number_of_old_vials =  Vial.count
    
    post :destroy_vial, { :id => vials(:vial_one).id }, user_session(:steve)
    
    assert_response :redirect
    assert_redirected_to :action => "list_vials"
    assert !flash.empty?
    assert_equal "First vial has been deleted",  flash[:notice]
    
    assert_nil Vial.find_by_id(vials(:vial_one).id)
    assert_equal number_of_old_vials - 1, Vial.count
  end
  
  def test_delete_vial_fails_when_NOT_logged_in
    post :destroy_vial, { :id => vials(:vial_one).id }
    assert_not_nil Vial.find_by_id(vials(:vial_one).id)
    assert flash.empty?
    assert_redirected_to_login
  end
  
  def test_delete_vial_fails_when_deleted_by_non_owner
    assert_equal users(:steve), vials(:vial_one).owner
    
    post :destroy_vial, { :id => vials(:vial_one).id }, user_session(:jeremy)
    
    assert_not_nil Vial.find_by_id(vials(:vial_one).id)
    assert_equal "You do not own that vial.", flash[:notice]
  end
  
  def test_index_page
    get :index, {}, user_session(:steve)
    
    assert_response :success
    assert_standard_layout
    assert_select "h1", "The Bench"
    assert_select "h2", "Fly and Vial Operations"
    assert_select "ul#fly_and_vial_operations" do
      assert_select "li", 3
      assert_select "li a[href=/bench/list_vials]", "List vials"
      assert_select "li a[href=/bench/mate_flies]", "Mate flies"
      assert_select "li a[href=/bench/collect_field_vial]", "Collect a field vial"
    end
    assert_select "h2", "Rack Operations"
    assert_select "ul#rack_operations" do
      assert_select "li", 1
      assert_select "li a[href=/bench/add_rack]", "Create a new rack"
    end
    assert_select "h2", "System Operations"
    assert_select "ul#system_operations" do
      assert_select "li", 3
      assert_select "li a[href=/bench/preferences]", "Set your preferences"
      assert_select "li a[href=/bench/choose_scenario]", "Choose a scenario"
      assert_select "li a[href=/users/change_password]", "Change your password"
    end
  end
  
  def test_collect_mate_data
    get :mate_flies, {}, user_session(:steve)
    assert_response :success
    assert_standard_layout
    
    assert_select "h2", "Cross the Flies"
    assert_select "form[action=/bench/mate_flies]" do
      assert_select "label", "Label for vial of offspring:"
      assert_select "input#vial_label"
      assert_select "label", "Number of offspring:"
      assert_select "input#vial_number_of_requested_flies"
      assert_select "label", /^Store in the rack named:/
      assert_select "select#vial_rack_id" do
        assert_select "option", 2, "steve should have two racks"
        assert_select "option", "steve stock"
        assert_select "option", "steve bench"
      end
      assert_select "input[type=submit][value=Cross]"
    end
  end
  
  def test_show_mateable_flies_for_first_vial
    xhr :post, :show_mateable_flies,
        { :vial_id => vials(:vial_one).id,
          :which_vial => "1"
          },
        user_session(:steve)
        
    assert_response :success
    assert_select_rjs :replace_html, "big-table-1" do
      assert_select "table" do
        assert_select "th", 32 * 5, "should have 2^5 * 5 table headers for 5 characters"
        assert_select "td", 32
        assert_select "th", :text => "female", :count => 16
        assert_select "th", :text => "male", :count => 16
        assert_select "th", :text => "red", :count => 16
        assert_select "th", :text => "white", :count => 16
        assert_select "th", :text => "straight", :count => 16
        assert_select "th", :text => "curly", :count => 16
        assert_select "th", :text => "smooth", :count => 16
        assert_select "th", :text => "hairy", :count => 16
        assert_select "th", :text => "short", :count => 16
        assert_select "th", :text => "long", :count => 16
        # TODO: need to assert radio buttons for flies
      end
    end
  end
  
  # TODO: assert radio buttons when showing mateable flies from vials(:vial_with_many_flies)
  
  def test_show_mateable_flies_for_second_vial
    xhr :post, :show_mateable_flies,
        { :vial_id => vials(:randy_vial).id,
          :which_vial => "2" },
        user_session(:randy)
        
    assert_response :success
    assert_select_rjs :replace_html, "big-table-2" do
      assert_select "table" do
        assert_select "th", 12 * 3
        assert_select "td", 12
        assert_select "th", :text => "female", :count => 6
        assert_select "th", :text => "male", :count => 6
        assert_select "th", :text => "smooth", :count => 6
        assert_select "th", :text => "hairy", :count => 6
        assert_select "th", :text => "no seizure", :count => 4
        assert_select "th", :text => "20% seizure", :count => 4
        assert_select "th", :text => "40% seizure", :count => 4
        # TODO: need to assert radio buttons for flies
      end
    end
  end
  
  def test_show_mateable_flies_back_to_instructions_for_first_vial
    xhr :post, :show_mateable_flies,
        { :vial_id => "0",
          :which_vial => "1" },
        user_session(:steve)
        
    assert_response :success
    assert_select_rjs :replace_html, "big-table-1" do
      assert_select "em.instruction", /^Select a vial/
    end
  end
  
  def test_show_mateable_flies_back_to_instructions_for_second_vial
    xhr :post, :show_mateable_flies,
        { :vial_id => "0",
          :which_vial => "2" },
        user_session(:steve)
        
    assert_response :success
    assert_select_rjs :replace_html, "big-table-2" do
      assert_select "em.instruction", /^Select a vial/
    end
  end
  
  def test_show_mateable_flies_fails_for_wrong_users
    good_params = {
        :vial_id => vials(:vial_one).id,
        :which_vial => "1"
      }
      
    xhr :post, :show_mateable_flies, good_params
    assert_redirected_to_login # no user logged in
    
    xhr :post, :show_mateable_flies, good_params, user_session(:manage_student)
    assert_response 401, "should reject non student"

    xhr :post, :show_mateable_flies, good_params, user_session(:randy)
    assert_response 401, "should reject non owner"
  end
  
  def test_show_mateable_flies_rejected_because_of_wrong_http_method
    good_params = {
        :vial_id => vials(:vial_one).id,
        :which_vial => "1"
      }
      
    xhr :get, :show_mateable_flies, good_params, user_session(:steve)
    assert_response 401, "should reject any get"
    
    post :show_mateable_flies, good_params, user_session(:steve)
    assert_response 401, "should reject normal post"
    
    get :show_mateable_flies, good_params, user_session(:steve)
    assert_response 401, "should reject any get"
  end
  
  def test_list_vials
    get :list_vials, {}, user_session(:steve)
    
    assert_response :success
    assert_standard_layout
    assert_select "h1", "Your Vials"
    assert_select "div#list-vials" do
      assert_select "h2", /Vials on the/
      assert_select "span#rack_label_2_in_place_editor", "steve bench"
      assert_select "ul#rack_2" do
        assert_select "li", 5
        assert_select "li#vial_1", "First vial"
        assert_select "li#vial_1 img[src^=/images/star.png][title=Solves Problem #8]"
        assert_select "li#vial_2", "Empty vial"
        assert_select "li#vial_2 img", false
        assert_select "li#vial_3", "Single fly vial"
        assert_select "li#vial_3 img", false
        assert_select "li#vial_4", "Multiple fly vial"
        assert_select "li#vial_4 img", false
        assert_select "li#vial_5", "Parents vial"
        assert_select "li#vial_5 img[src^=/images/star.png][title=Solves Problem #1]"
      end
    end
  end
  
  def test_list_vials_lists_only_current_users_vials
    get :list_vials, {}, user_session(:jeremy)
    
    assert_response :success
    assert_standard_layout
    assert_select "h1", "Your Vials"
    assert_select "div#list-vials" do
      assert_select "h2", /Vials on the/
      assert_select "span#rack_label_4_in_place_editor", "jeremy bench"
      assert_select "ul#rack_4" do
        assert_select "li", 2
        assert_select "li#vial_6", "Destroyable vial"
        assert_select "li#vial_6 img", false
        assert_select "li#vial_7", "Another vial"
        assert_select "li#vial_7 img[src^=/images/star.png]"
      end
    end
  end
  
  def test_list_vials_fails_when_NOT_logged_in
    get :list_vials
    assert_redirected_to_login
  end
  
  def test_mate_flies_page
    get :mate_flies, {}, user_session(:steve)
    
    assert_response :success
    assert_standard_layout
    
    assert_nil flash[:error]
    assert_select "div#vial_selector_1" do
      assert_select "select#first_vial_selector[onchange=onsubmit()]" do
        assert_select "option", 6
        assert_select "option[value=0][selected=selected]", ""
        assert_select "option[value=1]", "First vial"
        assert_select "option[value=2]", "Empty vial"
        assert_select "option[value=3]", "Single fly vial"
        assert_select "option[value=4]", "Multiple fly vial"
        assert_select "option[value=5]", "Parents vial"
      end
      assert_select "h2", "First Vial"
      assert_select "input[name=which_vial][value=1]"
      assert_select "img#spinner_1[src^=/images/green-load.gif]"
    end
    assert_select "div#vial_selector_2" do
      assert_select "select#second_vial_selector[onchange=onsubmit()]" do
        assert_select "option", 6
        assert_select "option[value=0][selected=selected]", ""
        assert_select "option[value=1]", "First vial"
        assert_select "option[value=2]", "Empty vial"
        assert_select "option[value=3]", "Single fly vial"
        assert_select "option[value=4]", "Multiple fly vial"
        assert_select "option[value=5]", "Parents vial"
      end
      assert_select "h2", "Second Vial"
      assert_select "input[name=which_vial][value=2]"
      assert_select "img#spinner_2[src^=/images/green-load.gif]"
    end
    assert_select "div#big-table-1"
    assert_select "div#big-table-2"
  end
  
  def test_mate_flies
    number_of_old_vials = Vial.count
    
    post :mate_flies,
    { :vial => {
        :label => "children vial",
        :mom_id => "6", :dad_id => "1",
        :rack_id => "2",
        :number_of_requested_flies => "8"
      } },
    user_session(:steve)
    
    new_vial = Vial.find_by_label("children vial")
    assert_not_nil new_vial
    
    assert_response :redirect
    assert_redirected_to :action => "view_vial", :id => new_vial.id
    
    assert_equal [:white] * 8, phenotypes_of(new_vial, :"eye color")
    assert_equal users(:steve), new_vial.owner
    assert_equal number_of_old_vials + 1, Vial.count
  end
  
  def test_mate_flies_again  
    post :mate_flies,
    { :vial => {
        :label => "children 2",
        :mom_id => "4", :dad_id => "3",
        :rack_id => "1", 
        :number_of_requested_flies => "3"
      } },
    user_session(:steve)
    
    new_vial = Vial.find_by_label("children 2")
    assert_not_nil new_vial
    
    assert_response :redirect
    assert_redirected_to :action => "view_vial", :id => new_vial.id
    
    assert_equal [:red] * 3, phenotypes_of(new_vial, :"eye color")
    assert_equal users(:steve), new_vial.owner
  end
  
  def test_mate_flies_fails_when_NOT_owned_by_current_user
    assert_no_added_vials do
      post :mate_flies, {
          :vial => {
            :label => "stolen children",
            :mom_id => "4", :dad_id => "3", 
            :number_of_requested_flies => "2",
            :rack_id => "2"
            } }, user_session(:jeremy)
            
      assert_response :success
      assert_standard_layout
      assert_template "bench/mate_flies"
      assert_nil Vial.find_by_label("stolen children")
    end
  end
  
  def test_mate_flies_redirects_when_NOT_logged_in
    assert_no_added_vials do
      post :mate_flies, {
          :vial => {
            :label => "children vial",
            :mom_id => "6", :dad_id => "1",
            :number_of_requested_flies => "8", :rack_id => "3" } }
            
      assert_redirected_to_login
    end
  end
  
  def test_mate_flies_errors_when_NO_parents_are_selected
    assert_no_added_vials do
      post :mate_flies, {
          :vial => {
            :label => "children vial",
            :number_of_requested_flies => "8",
            :rack_id => "2" }
          }, user_session(:steve)
          
      assert_response :success
      assert_standard_layout
      assert_template "bench/mate_flies"
      assert !assigns(:vial).valid?
      # other variations of this failure are tested in the unit tests
    end
  end
  
  def test_mate_flies_flashes_error_when_too_many_offspring_requested
    assert_no_added_vials do
      post :mate_flies,
          { :vial => {
              :label => "children vial",
              :dad_id => "1", :mom_id => 6, 
              :rack_id => "2",
              :number_of_requested_flies => "256" } },
          user_session(:steve)
          
      assert_response :success
      assert_standard_layout
      assert_template "bench/mate_flies"
      vial = assigns(:vial)
      assert vial.errors.invalid?(:number_of_requested_flies)
    end
  end
  
  def test_mate_flies_flashes_error_when_too_many_offspring_requested
    assert_no_added_vials do
      post :mate_flies,
          { :vial => {
              :label => "children vial",
              :dad_id => "1", :mom_id => 6, 
              :rack_id => "2",
              :number_of_requested_flies => "256" } },
          user_session(:steve)
          
      assert_response :success
      assert_standard_layout
      assert_template "bench/mate_flies"
      vial = assigns(:vial)
      assert vial.errors.invalid?(:number_of_requested_flies)
    end
  end
  
  def test_mate_flies_flashes_error_when_too_few_offspring_requested
    assert_no_added_vials do
      post :mate_flies,
          { :vial => {
              :label => "children vial",
              :dad_id => "1", :mom_id => 6, 
              :rack_id => "2",
              :number_of_requested_flies => "-1" } },
          user_session(:steve)
                  
      assert_response :success
      assert_standard_layout
      assert_template "bench/mate_flies"
      vial = assigns(:vial)
      assert vial.errors.invalid?(:number_of_requested_flies)
    end
  end
  
  def test_mate_flies_flashes_error_when_non_numeric_number_of_offspring_requested
    assert_no_added_vials do
      post :mate_flies,
          { :vial => {
              :label => "children vial",
              :dad_id => "1", :mom_id => 6, 
              :rack_id => "2",
              :number_of_requested_flies => "abc" } },
          user_session(:steve)
          
      assert_response :success
      assert_standard_layout
      assert_template "bench/mate_flies"
      vial = assigns(:vial)
      assert vial.errors.invalid?(:number_of_requested_flies)
    end
  end
  
  def test_preferences_page
    get :preferences, {}, user_session(:steve)
    assert_response :success
    assert_standard_layout
    assert_select "form" do
      assert_select "input[value=sex][checked=checked]"
      assert_select "input[value=eye color][checked=checked]"
      assert_select "input[value=wings][checked=checked]"
      assert_select "input[value=legs][checked=checked]"
      assert_select "input[value=antenna][checked=checked]"
      assert_select "input[type=checkbox][checked=checked]", 5
    end
  end
  
  def test_preferences_page_again
    get :preferences, {}, user_session(:randy)
    assert_response :success
    assert_standard_layout
    assert_select "form" do
      assert_select "input[value=sex][type=checkbox][checked=checked]"
      assert_select "input[value=eye color][type=checkbox][checked=checked]", 0
      assert_select "input[value=wings][type=checkbox][checked=checked]", 0
      assert_select "input[value=legs][type=checkbox][checked=checked]"
      assert_select "input[value=antenna][type=checkbox][checked=checked]", 0
      assert_select "input[value=seizure][type=checkbox][checked=checked]"
      assert_select "input[type=checkbox][checked=checked]", 3
    end
  end
  
  def test_preferences_page_again_with_scenario
    get :preferences, {}, user_session(:jeremy)
    assert_response :success
    assert_standard_layout
    assert_select "form" do
      assert_select "input[value=sex][type=checkbox][checked=checked]"
      assert_select "input[value=eye color][type=checkbox][checked=checked]"
      assert_select "input[value=wings][type=checkbox][checked=checked]"
      assert_select "input[value=legs][type=checkbox][checked=checked]", 0
      assert_select "input[type=checkbox][checked=checked]", 3
      assert_select "input[type=checkbox]", 4
    end
  end
  
  def test_change_preferences
    assert_equal 1, users(:steve).hidden_characters.size
    post :preferences, {:characters => ["sex", "wings", "antenna"]}, user_session(:steve)
    assert_response :redirect
    assert_redirected_to :controller => 'bench', :action => 'index'
    users(:steve).reload
    assert_equal [ :seizure, :"eye color", :legs], users(:steve).hidden_characters
    assert_equal [:sex, :wings, :antenna], users(:steve).visible_characters
    
    post :preferences, {:characters => ["sex", "wings", "legs"]}, user_session(:steve)
    assert_redirected_to :controller => 'bench', :action => 'index'
    users(:steve).reload
    assert_equal [:seizure, :"eye color", :antenna], users(:steve).hidden_characters
    assert_equal [:sex, :wings, :legs], users(:steve).visible_characters
  end
  
  def test_change_preferences_fails_when_NOT_logged_in_as_student
    post :preferences, {:characters => ["sex", "wings"]}
    assert_redirected_to_login
    
    number_of_old_preferences = CharacterPreference.find(:all)
    post :preferences, {:characters => ["sex", "legs"]}, user_session(:manage_student)
    assert_response 401 # access denied
    assert_equal number_of_old_preferences, CharacterPreference.find(:all)
  end
  
  def test_choose_scenario_page
    get :choose_scenario, {}, user_session(:randy)
    assert_response :success
    assert_standard_layout
    assert_select "form" do
      assert_select "select#scenario_id" do
        assert_select "option[value=1]", "forgetful instructor"
        assert_select "option", 1
      end
    end
  end
  
  def test_choose_scenario
    assert_nil users(:steve).current_scenario
    assert_equal 0, users(:steve).phenotype_alternates.size
    post :choose_scenario, { :scenario_id => 2 }, user_session(:steve)
    assert_response :redirect
    assert_redirected_to :controller => 'bench', :action => 'index'
    users(:steve).reload
    assert_equal scenarios(:another_scenario), users(:steve).current_scenario
    assert_equal [:"eye color", :"eye color"], 
    users(:steve).phenotype_alternates.map { |pa| pa.affected_character.intern }
    assert_equal [:red, :white].to_set, 
    users(:steve).phenotype_alternates.map { |pa| pa.original_phenotype.intern }.to_set
  end
  
  def test_choose_scenario_fails_when_NOT_scenario_for_course
    assert_nil users(:steve).current_scenario
    post :choose_scenario, { :scenario_id => 1 }, user_session(:steve)
    assert_response :redirect
    assert_redirected_to :controller => 'bench', :action => 'index'
    users(:steve).reload
    assert_nil users(:steve).current_scenario
  end
  
  def test_choose_scenario_fails_when_NOT_logged_in_as_student
    post :choose_scenario, { :scenario_id => 1 }
    assert_redirected_to_login
    
    post :choose_scenario, { :scenario_id => 1 }, user_session(:mendel)
    assert_response 401 # access denied
    
    post :choose_scenario, { :scenario_id => 1 }, user_session(:calvin)
    assert_response 401 # access denied
  end
  
  def test_choose_scenario_fails_when_NOT_valid_scenario_id
    old_scenario = users(:steve).current_scenario
    post :choose_scenario, { :scenario_id => 99999999999 }, user_session(:steve)
    assert_response :redirect
    assert_redirected_to :controller => 'bench', :action => 'index' # or something
    assert_equal old_scenario, users(:steve).current_scenario
  end

  #
  # Helpers
  #
  private
  
  def assert_no_added_vials
    original_number_of_vials = Vial.count
    yield
    assert_equal original_number_of_vials, Vial.count, "should have same number of vials"
  end
end