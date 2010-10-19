class SubjectsController < BaseController

  before_filter :login_required
  before_filter :find_subject, :only => [:show, :enroll]
  before_filter :find_user_subject, :only => [:edit,:destroy,:admin_show, :upload, :download]
  
  def find_subject
    @subject = Subject.find(params[:id])
    
    unless @subject
    flash[:notice] = "Curso não encontrado. Você digitou o endereço correto?"
    redirect_to subjects_path and return
    end
  end
  
  def find_user_subject
    @subject = current_user.subjects.find(params[:id])
    
    unless @subject
    flash[:notice] = "Curso não encontrado. Você tem mesmo permissão para acessá-lo?"
    redirect_to subjects_path and return
    end
  end

  def index
#    session[:subject_step] = session[:subject_params]= session[:subject_aulas]= session[:subject_id]= session[:subject_exames]  = nil
#    
#    if params[:school_id].nil?
#    @subjects = Subject.find(:all, :conditions => "is_public like true") 
#   else
#     @subjects = current_user.schools.find(params[:school_id]).subjects#.paginate(paginating_params)
#   end
#   
#   
#    respond_to do |format|
#     format.html # index.html.erb
#
#     format.js  do     
#       render :update do |page|
#         page.replace_html  'content_list', :partial => 'subjects/school/subject_list/'
#         page << "$('#spinner').hide()"
#       end
#     end  
#     
#   end

    session[:subject_step] = session[:subject_params]= session[:subject_aulas]= session[:subject_id]= session[:subject_exames]  = nil
    cond = Caboose::EZ::Condition.new
    cond.append ["simple_category_id = ?", params[:category]] if params[:category]
    
    paginating_params = {
      :conditions => cond.to_sql,
      :page => params[:page], 
      :order => (params[:sort]) ? params[:sort] + ' DESC' : 'created_at DESC', 
      :per_page => AppConfig.items_per_page 
    }
 
    if params[:user_id] # cursos do usuario
      @user = User.find_by_login(params[:user_id]) 
      @user = User.find(params[:user_id]) unless @user
      @subjects = @user.subjects.paginate(paginating_params)
      render((@user == current_user) ? "user_subjects_private" :  "user_subjects_public") #TODO
      return
      
    elsif params[:school_id] # cursos da escola
      @school = School.find(params[:school_id])
      if params[:search] # search cursos da escola
        @subjects = @school.subjects.name_like_all(params[:search].to_s.split).ascend_by_name.paginate(paginating_params)
      else
        @subjects = @school.subjects.paginate(paginating_params) 
      end
    else # index (Course)
      if params[:search] # search
        @subjects = Subject.name_like_all(params[:search].to_s.split).ascend_by_name.paginate(paginating_params)
      else
        @subjects = Subject.paginate(paginating_params)
      end
    end
    
    # @popular_tags = Course.tag_counts
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @subjects }
      
      format.js  do
        if params[:school_content]
          render :update do |page|
             page.replace_html  'content_list', :partial => 'subject_list'
             page << "$('#spinner').hide()"
          end
#        elsif params[:tab]
#          render :update do |page|
#            page.replace_html  'tabs-2-content', :partial => 'courses_school'
#          end
        else
          render :index
        end
        
      end
    end
 end
  

  def show
    
     @subject = Subject.find(:first, :conditions => "is_public like true AND id =#{params[:id].to_i}")
     @school = @subject.school
     
     student_profile = current_user.student_profiles.find_by_subject_id(@subject.id)
     @percentage = student_profile.nil? ? 0 : student_profile.coursed_percentage(@subject) 
     
    respond_to do |format|  
       if @subject.is_valid?  
         if current_user.enrollments.detect{|e| e.subject_id.eql?(params[:id].to_i)}.nil?
          format.html{  render "preview" }
        else
          @status = Status.new
          @statuses = @subject.recent_activity(0,10)
         format.html
        end
      else
       flash[:notice] = "Data do curso expirada"
       format.html{ redirect_to subjects_path}
      end
    
    end#format
 
  end

  def new
    session[:subject_params] ||= {}
   # cancel
    @subject = Subject.new
  end

  def create
    
    
    if params[:subject]
     params[:subject][:start_time] = Time.zone.parse(params[:subject][:start_time].gsub('/', '-')) unless params[:subject][:start_time].nil?
     params[:subject][:end_time] = Time.zone.parse(params[:subject][:end_time].gsub('/', '-'))  unless params[:subject][:end_time].nil?
     session[:subject_params].deep_merge!(params[:subject])  
    end
    session[:subject_aulas]= params[:aulas] unless params[:aulas].nil?
    session[:subject_exames] = params[:exams] unless params[:exams].nil?
    
    
    @subject = current_user.subjects.new(session[:subject_params])
    @subject.current_step = params[:step]#session[:subject_step] assim evita que ao dar refresh vá para o proximo passo
    
    if  @subject.valid?
      if params[:back_button]
        @subject.previous_step
      elsif @subject.last_step?
        
        if @subject.all_valid?
           @subject.save 
          @subject.create_course_subject_type_course(session[:subject_aulas], @subject.id, current_user) unless session[:subject_aulas].nil?
          @subject.create_course_subject_type_exam(session[:subject_exames], @subject.id, current_user) unless session[:subject_exames].nil?
          
        end
      else
        @subject.next_step
      end
      session[:subject_step]= @subject.current_step
    end

    if @subject.new_record?
      render "new"
    else
      session[:subject_step] = session[:subject_params]= session[:subject_aulas]=session[:subject_exames] = nil
       redirect_to admin_subjects_path 
    end
  end
  
  def cancel
    session[:subject_step] = session[:subject_params]= session[:subject_aulas]= session[:subject_id]= session[:subject_exames]  = nil
  end

  def edit
    session[:subject_params] ||= {} 
  end
 
  def update
     
    updated = false 
    if params[:subject]
     params[:subject][:start_time] = Time.zone.parse(params[:subject][:start_time].gsub('/', '-')) unless params[:subject][:start_time].nil?
     params[:subject][:end_time] = Time.zone.parse(params[:subject][:end_time].gsub('/', '-'))  unless params[:subject][:end_time].nil?
     session[:subject_params].deep_merge!(params[:subject])  
    end
    session[:subject_aulas]= params[:aulas] unless params[:aulas].nil?
    session[:subject_id]= params[:id].split("-")[0].to_i unless params[:id].nil?
    session[:subject_exames] = params[:exams] unless params[:exams].nil?
   
    @subject = current_user.subjects.new(session[:subject_params])
    @subject.current_step = params[:step]
 
    if  @subject.valid?
      if params[:back_button]
        @subject.previous_step
      elsif @subject.last_step?

        if @subject.all_valid?
          
          @subject = current_user.subjects.find(session[:subject_id])
          @subject.update_attributes(session[:subject_params])
           
          @subject.update_course_subject_type_course(session[:subject_aulas], @subject.id,current_user) #unless session[:subject_aulas].nil?
          @subject.update_course_subject_type_exam(session[:subject_exames], @subject.id, current_user) 
         updated = true
        end
          
      else
        @subject.next_step
      end
      session[:subject_step]= @subject.current_step
    end

    unless updated
       render "edit"
    else
      flash[:notice] = "Atualizado com sucesso!"
      session[:subject_step] = session[:subject_params]= session[:subject_aulas]= session[:subject_exames]= session[:subject_id] = nil
      redirect_to :action =>"admin_subjects"
    end

  end
 
  def destroy
    @subject.destroy
    redirect_to :action =>"admin_subjects"
  end

  def enroll
    begin
     redirect_to(subjects_path) and return unless @subject.is_public
     Enrollment.create_enrollment(@subject.id, current_user) 
     StudentProfile.create_profile(@subject.id, current_user)
     flash[:notice] = "Você se inscreveu neste curso!"
     redirect_to @subject
    rescue Exception => e #exceçao criada no model de Enrollment
      flash[:notice] =  e.message
      redirect_to subjects_path
    end
    
  end
  
  def upload
    @subject_file = @subject.subject_files.new
  end
  
  def attachment
    sf = current_user.subjects.find(params[:id]).subject_files.new
    sf.attachment = params[:subject_file][:attachment]
    sf.save 
    
    respond_to do |format|
     format.js
    end  
       
  end
  
  def download
    send_file "public/#{@subject.subject_files.find(params[:file_id]).attachment.url.split("?")[0]}", :type=>"application/zip"
  end
  
  def admin_subjects
    session[:subject_step] = session[:subject_params]= session[:subject_aulas]= session[:subject_id]= session[:subject_exames]  = nil
    @subjects = current_user.subjects
  end
  
  def admin_show
    @subject = current_user.subjects.find(params[:id])       
  end
     

end
