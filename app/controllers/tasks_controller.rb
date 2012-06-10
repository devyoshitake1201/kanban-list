# coding: utf-8
class TasksController < ApplicationController
  before_filter :authenticate_user!
  before_filter :books_list

  def books_list
    @books_list = current_user.books
  end

  def index
    @user_name = current_user.name
    @counts = get_task_counts
    @book_name = get_book_name
    @prefix = get_prefix

    @recent_done_num = 15
    @tasks = get_tasks( @recent_done_num )
  end

  def create
    @task = Task.new(:msg => params[:msg],
                     :name => current_user.name,
                     :user => current_user)
    @task.update_status(:todo_m)
    @task.book = get_book_id_in_msg(@task.msg)

    @task.save
    @counts = get_task_counts

    task_html = render_to_string :partial => 'task', :locals => {:task => @task, :display => "none" }

    render :json => { id: @task.id, li_html: task_html, task_counts: get_task_counts }, :callback => 'addTodoResponse'
  end

  def update
    task = Task.find(params[:id])
    task.update_status(params[:status])
    task.msg = params[:msg]
    task.book = get_book_id_in_msg(task.msg)
    task.save

    move_id = is_moved_from_book?(task) ? task.id : 0

    render :json => { task_counts: get_task_counts, move_task_id: move_id}, :callback => 'updateTaskJson'
  end

  def destroy
    task = Task.find(params[:id])
    task.delete

    render :json => get_task_counts, :callback => 'updateCountsJson'
  end

  def filter_or_update
    @user_name = current_user.name
    @recent_done_num = 15
    @book_name = get_book_name
    @prefix = get_prefix

    if params[:filter] != ""
      @tasks = get_filtered_tasks_by( current_user, params[:filter], @recent_done_num )
    else
      @tasks = get_tasks( @recent_done_num )
    end

    task_list_html = render_to_string :partial => 'tasklist'
    render :json => { task_list_html: task_list_html, task_counts: get_task_counts }, :callback => 'updateBookJson'
  end

  def donelist
    @tasks = current_user.tasks.by_status(:done)
    if params[:year].blank? == false
      select_month = Time.new( params[:year], params[:month])
      @tasks = @tasks.select_month(select_month)
    end
    @tasks = @tasks.paginate(:page => params[:page], :per_page => 100)

    @month_list = current_user.tasks.done_month_list
  end

  def send_mail
    mail_addr = params[:mail_addr]

    TaskMailer.all_tasks(current_user, get_book_name, mail_addr, get_tasks(@recent_done_num)).deliver
    render :json => { addr: mail_addr }, :callback => 'showMailResult'
  end

  private
  def get_book_id_in_msg(msg)
    #TODO: prefix と msg の分離は View でやるべき
    if /^【(.+)】/ =~ msg
      current_user.books.find_by_name($1) || nil
    else
      return nil
    end
  end

  def is_moved_from_book?(task)
    (current_book != nil) and (current_book.id != (task.book ? task.book.id : 0 ))
  end

  def get_filtered_tasks_by( user, filter_word, done_num = 10 )
    tasks = {
      :todo_high_tasks => user.tasks.by_status_and_filter(:todo_h,filter_word),
      :todo_mid_tasks  => user.tasks.by_status_and_filter(:todo_m, filter_word),
      :todo_low_tasks  => user.tasks.by_status_and_filter(:todo_l, filter_word),
      :doing_tasks     => user.tasks.by_status_and_filter(:doing,  filter_word),
      :waiting_tasks   => user.tasks.by_status_and_filter(:waiting,filter_word),
      :done_tasks      => user.tasks.by_status_and_filter(:done,   filter_word).limit(done_num),
    }
  end
end
