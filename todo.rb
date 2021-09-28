# frozen_String_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/contrib'

helpers do
  def is_list_completed?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if is_list_completed?(list) 
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed]}
  end

  def sorted_lists(lists, &block)
    incomplete_lists = {}
    complete_lists = {}
    lists.each_with_index do |list, index|
      if is_list_completed?(list)
        complete_lists[list] = index
      else
        incomplete_lists[list] = index
      end
    end
    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sorted_todos(todos)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed]}
    incomplete_todos.each { |todo| yield(todo, todos.index(todo))}
    complete_todos.each { |todo| yield(todo, todos.index(todo))}
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
  @session = session
end

get '/' do
  redirect '/lists', 302
end

get '/lists' do
  erb :lists, layout: :layout
end

get '/lists/new' do
  erb :new_list, layout: :layout
end

# return an error message if the name is invalid, returns nil if name is valid
def error_for_list_name(name)
  if session[:lists].any? { |list| list[:name] == name }
    'List name must be unique'
  elsif !(1..100).cover?(name.size)
    'list name must be between 1 and 100 chars.'
  end
end

def error_for_todo(name, list)
  if list[:todos].any? { |list| list[:name] == name }
    'todo name must be unique'
  elsif !(1..100).cover?(name.size)
    'todo name name must be between 1 and 100 chars.'
  end
end

def error_for_list_id(id)
  "This list doesn't exist" if !(0...session[:lists].size).cover?(id)
end

post '/lists/new' do
  list_name = params[:list_name].strip
  if (error = error_for_list_name(list_name))
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:message] = 'The list has been created.'
    redirect '/lists'
  end
end

get '/lists/:id' do
  @id = params[:id].to_i
  if (error = error_for_list_id(@id))
    session[:error] = error
    redirect "/lists"
  else
    @list = session[:lists][@id]
    erb :list, layout: :layout
  end
end


#adding todos to a list
post '/lists/:id' do
  todo = params[:todo].strip
  @id = params[:id].to_i
  @list = session[:lists][@id]
  if (error = error_for_todo(todo, @list))
    session[:error] = error
    erb :list, layout: :layout
  else
    session[:lists][@id][:todos] << {name: todo, completed: false}
    session[:message] = "Your todo has been added"
    redirect "/lists/#{@id}"
  end
end

get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

post '/lists/:id/edit' do
  id = params[:id].to_i
  list_name = params[:list_name].strip
  @list = session[:lists][id]
  if (error = error_for_list_name(list_name))
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:message] = 'The list name has been updated'
    redirect "/lists/#{id}"
  end
end

post '/lists/:id/delete' do
  session[:lists].delete_at(params[:id].to_i)
  session[:message] = 'The list has been deleted'
  redirect "/lists"
end

post '/lists/:id/:todo_index/delete' do
  list_idx = params[:id].to_i
  todo_idx = params[:todo_index].to_i
  session[:lists][list_idx][:todos].delete_at(todo_idx)
  session[:message] = "The ToDo has been deleted"
  redirect "/lists/#{list_idx}"
end

post '/lists/:id/:todo_index/update' do
  is_completed = params[:completed] == "true"
  list_idx = params[:id].to_i
  todo_idx = params[:todo_index].to_i
  todo = session[:lists][list_idx][:todos][todo_idx]
  todo[:completed] = is_completed
  redirect "/lists/#{list_idx}"
end

post '/lists/:id/complete-all' do
  list_idx = params[:id].to_i
  todos = session[:lists][list_idx][:todos]
  todos.each { |todo| todo[:completed] = true }
  session[:message] = "All ToDos have been completed"
  redirect "/lists/#{list_idx}"
end