# frozen_String_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
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
    lists.each_with_index do |list, _|
      if is_list_completed?(list)
        complete_lists[list] = list[:id]
      else
        incomplete_lists[list] = list[:id]
      end
    end
    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def h(content)
    Rack::Utils.escape_html(content)
  end

  def sorted_todos(todos)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed]}
    incomplete_todos.each { |todo| yield(todo)}
    complete_todos.each { |todo| yield(todo)}
  end
end

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

def load_list(id)
  list = session[:lists].find { |list| list[:id] == id } if id && session[:lists].find { |list| list[:id] == id }
  return list if list

  session[:error] = "This list doesn't exist"
  redirect "/lists"
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0 
  max + 1
end

def next_list_id(lists)
  max = lists.map { |list| list[:id]}.max || 0
  max + 1
end

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
  @session = session
end

get '/' do
  redirect '/lists', 302
end

get '/lists' do
  p session[:lists]
  erb :lists, layout: :layout
end

get '/lists/new' do
  erb :new_list, layout: :layout
end

# return an error message if the name is invalid, returns nil if name is valid


post '/lists/new' do
  list_name = params[:list_name].strip
  if (error = error_for_list_name(list_name))
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { id: next_list_id(session[:lists]), name: list_name, todos: [] }
    session[:message] = 'The list has been created.'
    redirect '/lists'
  end
end



get '/lists/:id' do
  @id = params[:id].to_i
  @list = load_list(@id)
  erb :list, layout: :layout
end


#adding todos to a list
post '/lists/:id' do
  todo = params[:todo].strip
  @id = params[:id].to_i
  @list = load_list(@id)
  if (error = error_for_todo(todo, @list))
    session[:error] = error
    erb :list, layout: :layout
  else
    todo_id = next_todo_id(@list[:todos])
    @list[:todos] << {id: todo_id, name: todo, completed: false}
    session[:message] = "Your todo has been added"
    redirect "/lists/#{@id}"
  end
end

get '/lists/:id/edit' do
  @id = params[:id].to_i
  @list = load_list(@id)
  erb :edit_list, layout: :layout
end

post '/lists/:id/edit' do
  @id = params[:id].to_i
  list_name = params[:list_name].strip
  @list = load_list(@id)
  if (error = error_for_list_name(list_name))
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:message] = 'The list name has been updated'
    redirect "/lists/#{@id}"
  end
end

post '/lists/:id/delete' do
  list_id = params[:id].to_i
  session[:lists].reject!{ |list| list[:id] == list_id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:message] = 'The list has been deleted'
    redirect "/lists"
  end
end

post '/lists/:id/:todo_id/delete' do
  list_id = params[:id].to_i
  todo_id = params[:todo_id].to_i
  session[:lists].find { |list| list[:id] == list_id }[:todos]
                 .delete_if { |todo| todo[:id] == todo_id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:message] = "The ToDo has been deleted"
    redirect "/lists/#{list_id}"
  end
end

#CHANGE ID AND IDX
post '/lists/:id/:todo_id/update' do
  is_completed = params[:completed] == "true"
  list_id = params[:id].to_i
  todo_id = params[:todo_id].to_i
  todo = session[:lists].find { |list| list[:id] == list_id }[:todos]
                        .select { |todo| todo[:id] == todo_id }
                        .first
  todo[:completed] = is_completed
  redirect "/lists/#{list_id}"
end

post '/lists/:id/complete-all' do
  list_id = params[:id].to_i
  todos = session[:lists].find { |list| list[:id] == list_id }[:todos]
  todos.each { |todo| todo[:completed] = true }
  session[:message] = "All ToDos have been completed"
  redirect "/lists/#{list_id}"
end