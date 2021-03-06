module UsersHelper

  def get_char(type)
    #duplication with @@all_page_aliases and filter   
    return 'l' if type == "likes"
    return 'm' if type == "music"
    return 'b' if type == "books"
    return 'v' if type == "movies"
    return 't' if type == "television"
    return 'g' if type == "games"
    return 'a' if type == "activities"
    return 'i' if type == "interests"
    return 'x' #shouldn't happen   
  end

  def date_to_age(birthday) #not a methood so we can do it before save and use update attributes
    #dumb americans            
    begin
      birthday=birthday.split("/")
      month=birthday[0]
      day=birthday[1]
      birthday[0]=day
      birthday[1]=month
      birthday=birthday.join("/") 
      dob = Time.parse(birthday)
      now = Time.now.utc.to_date
      age = now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)           
    rescue
      return nil #because user didn't tell his birthday to facebook
    end
    begin
      return nil if (age == 0 || age == -1) #because user didn't tell his birth year
      return age
    rescue
      return nil 
    end    
  end

  
  #sarit stuff
  def get_rank
    return "leet" if reputation > 100
    return "noob"
  end
  
  def get_badges
    my_bedges = []
    my_bedges<<"icon.png" if self.reputation > -2
    my_bedges<<"rails.png" if self.credit > -2
    return my_bedges
  end
  
  def get_recommended_pages
    my_pages = []
    page_filter ||= PageFilter.new
    self.find_pages(page_filter).first(6).each {|page| my_pages<<page[0]}
    return my_pages
  end
  
  def get_questions(n)
    n=1
    Question.order("RANDOM()").limit(n)  
  end
    
end









############################# here is some old code #############################

=begin
  def retrive_and_save_batch_old(graph,users_id_array)
    batch_results = graph.batch do |batch_api|#array of arraies of hashes
      users_id_array.each do |id|
        @@all_page_types.each do |type|
          batch_api.get_connections(id, type)
        end          
      end   
    end
    pursed_batch = batch_results.each_slice(@@weights.count).to_a #every element is an array with all info on a user
    data_hash = Hash[users_id_array.zip pursed_batch] #hash of 6 users, user_id=>array of arraies the contain likes, books, movies...
    #raise graph.get_connections("509006501", "likes").to_s   can't get data on some people...
    
    # save the new pages
    all_pages_id = Page.all.pluck(:id) #todo: change so I won't take all pages to memory move to save db entries   
    batch_likes=data_hash.values.flatten
    batch_pages = []
    batch_likes.each do |like|      
      #for some reson there is a nil in the like array
      batch_pages << Page.new(:category=>like["category"], :name=>like["name"], :id=>like["id"]) unless like==nil
    end
    
    batch_pages = batch_pages.uniq
    batch_pages = batch_pages.delete_if{ |page|all_pages_id.include?(page.id.to_i) } unless batch_pages==nil #faster but won't notice if the page name changes
    batch_pages.each do |page|
      page["id"] = page["id"]
    end 
    
    Page.import batch_pages 
    
    # save user_page_relationships
    ActiveRecord::Base.transaction do
      data_hash.each do |user_id,category| #category is an array of arrays [[likes],[books],...]
        #raise category.to_s
        ActiveRecord::Base.connection.execute("DELETE FROM user_page_relationships WHERE user_id = #{user_id}")
        data_hash[user_id] = Hash[@@all_page_aliases.zip category]     
      end
      #raise data_hash.to_s    
      user_page_relationship_array = []
      data_hash.each do |user_id,category|
        category.each do |category_name,like_array|
          unless like_array == nil
            like_array.each do |like|
              user_page_relationship_array << UserPageRelationship.new(:relationship_type => category_name,:user_id => user_id,:page_id => like["id"])
              #user_page_relationship_array.push({:fb_created_time => like["created_time"],:relationship_type => category_name,:user_id => user_id,:page_id => like["id"]})
            end
          end        
        end           
      end
      UserPageRelationship.import user_page_relationship_array
    end
  end

=end

=begin
  def insert_my_info_to_db(my_graph) #works but doesn't update existing non active users data
    
    
    my_friends_id = my_graph.get_connections("me", "friends")
    
    
    my_friends_id_array = []
    my_friends_id.each do |fb_friend|
      my_friends_id_array.push(fb_friend["id"])
    end    
    grouped_id_array = my_friends_id_array.each_slice(50).to_a
    my_friends = []
    grouped_id_array.each do |id_array|
      batch_results = my_graph.batch do |batch_api|#array of arraies of hashes
        id_array.each do |id|
          batch_api.get_object(id)         
        end   
      end
      my_friends.push(batch_results)
    end
    my_friends = my_friends.flatten.compact
    friends_array = []
    my_friends.each do |fb_friend|
      #sometimes for some friends not all the info I can see on their profile gets to likeme from facebook... is that a privacy thing?
      friends_array << User.new(
      :id => fb_friend["id"],
      :name => fb_friend["name"],
      :location => fb_friend["location"],
      :birthday => fb_friend["birthday"],
      :hometown => fb_friend["hometown"],
      :quotes => fb_friend["quotes"],
      :relationship_status => fb_friend["relationship_status"],
      :significant_other => fb_friend["significant_other"],
      :gender => fb_friend["gender"],
      :age => date_to_age(fb_friend["birthday"]),
      :bio => fb_friend["bio"])        
    end
    #todo do not reject+import, use update+insert on all
    existing_friends_id = User.where(:id => my_friends_id_array).pluck(:id)
    friends_array = friends_array.reject { |friend|  existing_friends_id.include?(friend["id"])}
    User.import friends_array unless friends_array.blank?
      
    #frienships
    my_id = self.id.to_s 
    my_friends_id_array = []
        my_friends_id.each do |fb_friend|
      my_friends_id_array.push("(" + my_id + "," + fb_friend["id"] + ")")
    end
    my_friends_id_string=my_friends_id_array.to_s.gsub!("\"", "")
    #do it better with db constraints and no deletion? one transaction?
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("DELETE FROM friendships WHERE user_id = #{my_id}")
      ActiveRecord::Base.connection.execute("INSERT INTO friendships (user_id, friend_id) VALUES #{my_friends_id_string[1..-2]}")
    end
    #insert friends info
    ActiveRecord::Base.connection.reconnect!
    insert_batches_info(my_graph,my_friends) #losing connection here?
    ActiveRecord::Base.connection.reconnect!
    self.last_fb_update = Time.now
    self.save!
  end
=end


=begin
  def insert_self_data_and_likes_old(my_graph) #works fine, 0.2 sec slower
    fb_me = my_graph.get_object("me")
    db_me = insert_friend_to_db(fb_me)
    
    my_id = db_me.id
    user_page_relationship_array = []
    page_array = []
    
    batch_results = my_graph.batch do |batch_api|#todo finish
      @@all_page_types.each do |category|
        batch_api.get_connections(my_id, category)          
      end
    end   
    #raise batch_results.to_s
    category_counter = 0
    @@all_page_types.each do |category|
      my_likes = batch_results[category_counter]
      category_char = get_char(category)      
      my_likes.each do |like|
        user_page_relationship_array << UserPageRelationship.new(:relationship_type => category_char,:user_id => my_id,:page_id => like["id"]) #unless like.blank?
        page_array << Page.new(:category => like["category"], :name => like["name"], :id => like["id"]) #unless like.blank?      
      end
      category_counter = category_counter+1
    end

    #remove existing pages and duplications from page array
    existing_pages_id = Page.where(:id => page_array.map(&:id)).pluck(:id)
    page_array = page_array.reject { |page|  existing_pages_id.include?(page["id"])}
    page_hash = Hash.new
    page_array.each do |page|
      page_hash[page["id"]] = page
    end
    page_array = page_hash.values    

 
    Page.import page_array unless page_array.blank?
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("DELETE FROM user_page_relationships WHERE user_id = #{my_id}")
      UserPageRelationship.import user_page_relationship_array unless user_page_relationship_array.blank?
    end

  end
=end
















#fb_like looks like this:
#{"category"=>"Book", "name"=>"1984", "id"=>"111757942177556", "created_time"=>"2013-02-02T01:14:50+0000"}

#fb_user looks like this:
#{"id"=>"584663600", "name"=>"Alon Rozental", "first_name"=>"Alon", "last_name"=>"Rozental", "link"=>"http://www.facebook.com/alon.rozental.3", "username"=>"alon.rozental.3", "birthday"=>"12/20/1986", "hometown"=>{"id"=>"106371992735156", "name"=>"Tel Aviv, Israel"}, "location"=>{"id"=>"106371992735156", "name"=>"Tel Aviv, Israel"}, "quotes"=>"\"It's a man's obligation to stick his boneration in a women's separation; this sort of penetration will increase the population of the younger generation.\" \n-E. Cartman\n\nSookie.\n-Bill compton", "education"=>[{"school"=>{"id"=>"176662212386543", "name"=>"Tel Aviv University | אוניברסיטת תל-אביב"}, "year"=>{"id"=>"140617569303679", "name"=>"2007"}, "type"=>"Graduate School"}], "gender"=>"male", "relationship_status"=>"In a Relationship", "significant_other"=>{"name"=>"Jenia Skorski", "id"=>"100001439566738"}, "religion"=>"Flying Spaghetti Monsterism", "political"=>"Transhumanism", "email"=>"alonzorz1@gmail.com", "timezone"=>2, "locale"=>"en_GB", "languages"=>[{"id"=>"108405449189952", "name"=>"Hebrew"}, {"id"=>"106059522759137", "name"=>"English"}], "verified"=>true, "updated_time"=>"2013-02-04T10:26:03+0000"}


  #set_primary_key :id
  #before_save :make_id
  #before_validation :make_id
  #validates_uniqueness_of :id

  
  def my_type_score_with(user,type) #todo: 4 db calls that can be reduced to 2 in exchange for readability
    my_favorites_pid = self.user_page_relationships.where(:relationship_type => type).map(&:page_id)
    user_likes_pid = user.user_page_relationships.where(:relationship_type => "likes").map(&:page_id)
    
    user_favorites_pid = user.user_page_relationships.where(:relationship_type => type).map(&:page_id)   
    my_likes_pid = self.user_page_relationships.where(:relationship_type => "likes").map(&:page_id)
    
    my_score = ((my_favorites_pid & user_likes_pid).count.to_f)/(my_favorites_pid.count + 1)
    user_score = ((user_favorites_pid & my_likes_pid).count.to_f)/(user_favorites_pid.count + 1)
    
    return (my_score+user_score)/2.0  
  end
  
  def insert_my_info_to_db_old(my_graph)
    #my user to db
    fb_me = my_graph.get_object("me")
    db_me = insert_friend_to_db(fb_me)
    insert_friend_info(my_graph,db_me)
    
    #my friends to db
    my_friends = my_graph.get_connections("me", "friends")
    my_friends.each do |fb_friend|
      db_friend = insert_friend_to_db(fb_friend)
      insert_friend_info(my_graph,db_friend) #unless db_friend.last_fb_update was shortly #work on worker
    end
  end
  #handle_asynchronously :insert_my_info_to_db


  def find_matches_old#(filter)  #main matching algorithm, returns sorted hash of {uid => score}      
    users = User.all#.sample(7) #.where(filter)
    user_type_scores = Hash.new
    users_scores = Hash.new
    users.each do |user|
      @@all_page_types.each do |type|
        user_type_scores[type] = my_type_score_with(user,type)*@@weights[type].to_f unless (@@weights[type] == 0)
      end
      user_total_score = user_type_scores.values.inject{ |sum, el| sum + el }.to_f / user_type_scores.values.size
      users_scores[user.uid] = user_total_score
      user_type_scores = Hash.new

    end
    users_scores = users_scores.sort_by { |uid, score| score }
    return users_scores.reverse
  end


  def match_by_most_shared_pages
    my_pages_pid = self.pages.map(&:pid)
    users = User.all
    users_and_their_good_pages = Hash.new
    users.each do |u|
      user_pages_pid = u.pages.map(&:pid)
      user_shared_pages = user_pages_pid & my_pages_pid
      users_and_their_good_pages[u.uid] = user_shared_pages
    end
    
    sorted_users_and_their_good_pages = users_and_their_good_pages.sort_by { |uid, user_shared_pages| user_shared_pages.count }
    
    return sorted_users_and_their_good_pages.reverse
  end


=begin
  def insert_friend_pages(my_graph,db_friend,type)
    friend_likes = my_graph.get_connections(db_friend.id, type)
    friend_id = db_friend.id
    page_array = []
    user_page_relationship_array = []


    friend_likes.each do |like|
      #page_array.push(Page.new(:id => like["id"],:id => like["id"],:name => like["name"],:category => like["category"]))
      #user_page_relationship_array.push(UserPageRelationship.new(:fb_created_time => like["created_time"],:relationship_type => type,:user_id => friend_id,:page_id => like["id"]))
      page_array.push({:id => like["id"],:id => like["id"],:name => like["name"],:category => like["category"]})
      user_page_relationship_array.push({:relationship_type => type,:user_id => friend_id,:page_id => like["id"]})

    end
    
    all_pages_id = Page.where(:id => page_array.map(&:id)).map(&:id)
    #all_pages_id = Page.all.map(&:id) #move
     
    page_array.delete_if{ |page|all_pages_id.include?(page[:id].to_i) } unless page_array==nil #faster but won't notice if the page name changes        
    Page.create(page_array)
    
    #db_friend.user_page_relationships = user_page_relationship_array# forgets the user_id???
    ActiveRecord::Base.connection.execute("DELETE FROM user_page_relationships WHERE user_id = #{db_friend.id}")
    UserPageRelationship.create(user_page_relationship_array)
  end
=end


  
=begin
  def time_fb_connection(my_graph)
    start_time = Time.now
    my_friends = my_graph.get_connections("me", "friends")
    my_friends.each do |fb_friend|
      @@all_page_types.each do |type|
        friend_likes = my_graph.get_connections(fb_friend["id"], type)
      end      
    end
    end_time = Time.now
    return end_time-start_time
  end
=end
    
=begin  
  def insert_friend_info(my_graph,db_friend)    
    @@all_page_types.each do |type|
      insert_friend_pages(my_graph,db_friend,type) 
    end
  end
  #handle_asynchronously :insert_friend_info
=end    
  
=begin 
  def self.from_omniauth(auth)
    user = User.where(auth.slice(:provider, :uid)).first_or_initialize
    user.update_attributes({
      :provider => auth.provider,
      :uid => auth.uid,
      :id => auth.uid,
      :name => auth.info.name,
      :oauth_token => auth.credentials.token,
      :oauth_expires_at => Time.at(auth.credentials.expires_at)     
    })
  end
=end

=begin 
  def insert_friend_pages_old(my_graph,db_friend,type) #todo books and movies, not only likes
    friend_likes = my_graph.get_connections(db_friend.uid, type)
    friend_likes.each do |like|
      db_page = Page.find_or_initialize_by_id(like["id"])
      db_page.update_attributes({
               :pid => like["id"],
               :name => like["name"],
               :category => like["category"]
            })
      relationship = UserPageRelationship.find_or_initialize_by_user_id_and_page_id_and_relationship_type(db_friend.id,db_page.id,type)
      relationship.update_attributes({
         :fb_created_time => like["id"],
         :relationship_type => type
      })
    end                  
  end

  def insert_friend_pages_new(my_graph,db_friend,type) #todo books and movies, not only likes
    friend_fb_likes = my_graph.get_connections(db_friend.uid, type)
    friend_db_likes = []
    friend_id = db_friend.id
    friend_fb_likes.each do |like|
      friend_db_likes.push(Page.new(#problem, only adds 1 relationship per user, is it fixed?
        :id => like["id"],
        :pid => like["id"],
        :name => like["name"],
        :category => like["category"],        
        :user_page_relationships_attributes => [{ :fb_created_time => like["created_time"],:relationship_type => type,:user_id => friend_id,:page_id => like["id"]}]))

    end
    #raise "erroWWWWWWr" if (db_friend.pages.map(&:id) != db_friend.pages.map(&:id).uniq) we can get same page with different connections
    db_friend.pages = friend_db_likes 
    db_friend.save               
  end
=end   


  
  
  
=begin  
  def insert_my_info_to_db_old(my_graph)
    #my user to db
    fb_me = my_graph.get_object("me")
    db_me = User.find_or_initialize_by_uid(fb_me["id"])
      db_me.update_attributes({
         :uid => fb_me["id"],
         :name => fb_me["name"],
         :location => fb_me["location"]
      })

    #my pages and relationships to db
    insert_friend_info(my_graph,db_me)
    
    #my friends to db
    my_friends = my_graph.get_connections("me", "friends")
    my_friends.each do |fb_friend|
      db_friend = User.find_or_initialize_by_uid(fb_friend["id"])
      db_friend.update_attributes({
         :uid => fb_friend["id"],
         :name => fb_friend["name"],
         :location => fb_me["location"]         
      })
      #friends pages and relationships to db
      insert_friend_info(my_graph,db_friend) #unless db_friend.last_fb_update #work on worker

      db_friend.update_attributes(:last_fb_update => Time.now) #update timestamp  #Time.now.to_time.to_i = stamp
    end
  end
  #handle_asynchronously :insert_my_info_to_db
=end




=begin  
  def make_id
    self.id = self.uid
  end
  
  def existing_pages_id(page_array) #doesn't really belong here
    #remove duplications, I don't think I need it 
    page_hash = Hash.new
    page_array.each do |page|
      page_hash[page["id"]] = page
    end
    #teimed_page_array = page_hash.values
    #return teimed_page_array
    

    #set the @new_record instance variable
    all_pages_id = Page.all.map(&:pid)
    my_pages_id = page_hash.keys
    existing_pages_id = my_pages_id & all_pages_id
    return existing_pages_id
    #raise existing_pages.to_s
  end
=end 




=begin
  
  def find_matches_incomplete_raw_sql(filter)  #main matching algorithm, returns sorted hash of {uid => score}
    users = User.where({}) #.where(filter)sample(5) 
    users = users.where(:gender => filter.gender) unless filter.gender==nil
    users = users.where("age <= ?", filter.max_age) unless filter.max_age==nil #todo: is it always valid when no age available? 
    users = users.where("age >= ?", filter.min_age) unless filter.min_age==nil
    users = users.all
    my_pages = self.user_page_relationships.group_by(&:relationship_type) #hash: key=type, value=array of pages
    @@all_page_types.each {|t|  my_pages[t] ||= []  } 
    
    users_id = users.map(&:id) #array of user id's
    likes_id = ActiveRecord::Base.connection.execute("SELECT `user_page_relationships`.*  FROM `user_page_relationships` WHERE `user_page_relationships`.`user_id` IN (#{users_id.to_s[1..-2]})")    
    
    raise likes_id.to_a.to_s
    user_type_scores = Hash.new
    users_scores = Hash.new
    
    #@result.map(&:ingredient_id)
    #users_id.to_s[1..-2]
    #the .each is when the db is actually querried, takes about 0.1 seconds per person
    #nevertheless the db query says it was done in 0.3 seconds for everyone (instead of ~ 20 seconds)
    #maybe preparing the query is the thing that takes all the time...
    #@@t = Time.now
    #ActiveRecord::Base.connection.execute("SELECT `user_page_relationships`.* FROM `user_page_relationships` WHERE `user_page_relationships`.`user_id` IN (403087, 4812944, 7814088, 7951570, 500758940, 509006501, 509235222, 509298645, 523324821, 531468362, 531748935, 534017701, 534942713, 537060876, 540004381, 541213350, 543930569, 555591679, 557554734, 557719165, 561968411, 568421699, 568772885, 570792851, 571161358, 571563453, 576723673, 580911797, 584287703, 584564993, 584663600, 588985921, 599771872, 611879300, 614157428, 614227748, 617074707, 617129409, 618258205, 624689387, 625787186, 628416504, 629569657, 634430395, 640236622, 641290282, 641906096, 642989928, 645624017, 649154511, 651956881, 652977224, 654736616, 663263604, 664444456, 670809202, 672281583, 672712500, 674098492, 679192308, 679932935, 681317849, 683720743, 684456826, 684483524, 688591863, 690782893, 692543926, 698928679, 699927021, 700251910, 701907883, 704779466, 706709402, 706953507, 708916298, 716338621, 718198175, 718599261, 720780340, 721879451, 722216637, 726202564, 728014683, 728264937, 728773216, 729318980, 730669263, 732088883, 733006140, 733036288, 735143424, 742552901, 742654607, 743168191, 743282086, 745368651, 750447972, 756987511, 757953555, 759841109, 764511177, 767923815, 771658648, 774963146, 779473531, 785294809, 798299094, 805074507, 807829678, 820563738, 822514518, 898920631, 904170122, 1009050478, 1020838859, 1027824259, 1029177407, 1037472934, 1049643909, 1050876972, 1051714764, 1055849757, 1062280398, 1068846474, 1070257630, 1074963269, 1078580550, 1121611112, 1125919485, 1147650208, 1157990697, 1172158073, 1177177649, 1216591815, 1220498362, 1227427601, 1248032322, 1257168412, 1275158521, 1312509306, 1337234639, 1353862945, 1391790937, 1429105586, 1448400429, 1491370061, 1495533321, 1499568723, 1540935619, 1551171041, 1557200592, 1567731573, 1615043263, 1634673238, 1641458923, 100000007029692, 100000134438771, 100000267359031, 100000418861151, 100000455541737, 100000521728172, 100000601440273, 100000962837133, 100001137434872, 100001157526295, 100001387090980, 100001439566738, 100001584939590, 100001976796576, 100002146507225, 100002204450918, 100002529593444)")    
    #raise (Time.now-@@t).to_s
    
    users.each do |user| 
      user_pages = user.user_page_relationships.group_by(&:relationship_type)
      #raise user_pages.to_s
      if user_pages.blank?
        user_type_scores = [0.0]
      else
        user_type_scores = user_pages.map do |type, page_array| #error if no likes
          next if (@@weights[type] == 0)        
          my_score = ((my_pages[type].map(&:page_id) & user_pages['likes'].map(&:page_id)).count.to_f)/(my_pages[type].count + 1)
          user_score = ((user_pages[type].map(&:page_id) & my_pages['likes'].map(&:page_id)).count.to_f)/(user_pages[type].count + 1)
          score = ((my_score+user_score) / 2.0) * @@weights[type].to_f
          score  
        end
      end
      
      user_type_scores.compact!
      user_total_score = user_type_scores.inject{ |sum, el| sum + el }.to_f / user_type_scores.size
      user_chosen_likes = []
      begin
      user_chosen_likes = user_pages["likes"].sample(6).map(&:page_id)
      rescue
      end
      users_scores[user.uid] = [user_total_score,user_chosen_likes]

    end
    users_scores = users_scores.sort_by { |uid, score| score[0] }
    return users_scores.reverse
  end 
=end


=begin
    #my user to db
    fb_me = my_graph.get_object("me")
    db_me = insert_friend_to_db(fb_me)
    #insert_friend_info(my_graph,db_me)

    my_friends_id = my_graph.get_connections("me", "friends") #an array of hashes {"name" => "dan", "id" => "111"}
    
    my_id = self.id.to_s 
    my_friends_id_array = []
        my_friends_id.each do |fb_friend|
      my_friends_id_array.push("(" + my_id + "," + fb_friend["id"] + ")")
    end
    my_friends_id_string=my_friends_id_array.to_s.gsub!("\"", "")
    #do it better with db constraints and no deletion:
    ActiveRecord::Base.connection.execute("DELETE FROM friendships WHERE user_id = #{my_id}")
    ActiveRecord::Base.connection.execute("INSERT INTO friendships (user_id, friend_id) VALUES #{my_friends_id_string[1..-2]}")
=end


=begin 
  def insert_batches_info(my_graph,my_friends)
    raise my_friends.to_s 
    my_id = self.id.to_s
    id_array = [] 
    my_friends.each do |friend|
      id_array.push(friend["id"]) unless friend==nil
    end
    grouped_id_array = id_array.each_slice(50/(@@weights.count)).to_a #so we will have no more than 50 requests in a batch
    
    ########################################### old single processed way
    
      #grouped_id_array.each do |group|
      #  retrive_and_save_batch(my_graph,group)
      #end
      Parallel.each(grouped_id_array, :in_processes => @@cores) do |group|
        begin
          ActiveRecord::Base.connection.reconnect!
          retrive_and_save_batch(my_graph,group)
        rescue
        end
      end
    ###########################################
   
    chunked_grouped_id_array = grouped_id_array.in_groups(@@cores,false)
    ActiveRecord::Base.clear_all_connections!
    chunked_grouped_id_array.each do |chunk|
      Process.fork do #todo open less forking (in processes 3)
        ActiveRecord::Base.establish_connection
        chunk.each do |group|
          retrive_and_save_batch(my_graph,group)
        end
      end
    end
    Process.waitall
    ActiveRecord::Base.establish_connection

  end
=end

=begin
def find_matches(filter)  #with random likes
    self.calculate_scores
    users = filter.get_scope(self.id)
 
    #raise "k"



    #raise users.class.to_s
    #users = users.all
    #raise users[0].id.to_s
    
    my_pages = self.user_page_relationships.group_by(&:relationship_type) #hash: key=type, value=array of pages
    @@all_page_aliases.each {|t|  my_pages[t] ||= []  } 
   
    user_type_scores = Hash.new
    users_scores = Hash.new
    

    results = Parallel.map(users, :in_processes=>LikeMeConfig::matching_cores) do |user| 
      user_pages = user.user_page_relationships.group_by(&:relationship_type)
      if user_pages.blank?
        user_type_scores = [0.0]
      else
        user_type_scores = user_pages.map do |type, page_array| #error if no likes
          next if (@@weights[type] == 0 )
          begin        
            my_score = ((my_pages[type].map(&:page_id) & user_pages['l'].map(&:page_id)).count.to_f)/(my_pages[type].count + 1)
          rescue
            my_score = 0
          end
          begin
            user_score = ((user_pages[type].map(&:page_id) & my_pages['l'].map(&:page_id)).count.to_f)/(user_pages[type].count + 1)
          rescue
            my_score = 0
          end
          score = ((my_score+user_score) / 2.0) * @@weights[type].to_f
          score  
        end
      end
      
      user_type_scores.compact!
      user_total_score = user_type_scores.inject{ |sum, el| sum + el }.to_f / user_type_scores.size
      user_chosen_likes = []
      begin
      user_chosen_likes = user_pages[get_char(filter.search_by)].sample(6).map(&:page_id) #choose whet type pf likes to show
      rescue
      end
      user_total_score = (user_total_score/(6-user_chosen_likes.size) - 0.000001*(6-user_chosen_likes.size)) if user_chosen_likes.size<6 #don't want them in the top 5
      users_scores[user.id] = [user.id,user_total_score,user_chosen_likes]
    end
    results.each do |score_array|
      users_scores[score_array[0]] = [score_array[1],score_array[2]]
    end
    #raise users_scores.to_s
    users = users.to_a.sort_by {|user| users_scores[user["id"]][0]*(-1)}
    users_and_likes = []
    users.each do |user|
      users_and_likes << [user,users_scores[user.id][1]]
    end
    #raise users_and_likes.to_s
    #users_objects = User.where(:id => users_scores.keys).all already have it
    users_scores = users_scores.sort_by { |id, score| score[0]*(-1) }
    #raise users_scores.to_s
    #users_order = users_scores.collect {|x| x[0]}.to_s
    #users_objects = User.where(:id => users_scores.keys)
    #return users_scores
    #raise users_and_likes.size.to_s
    #raise users_and_likes.to_s
    return users_and_likes
  end
=end
=begin
  def calculate_scores # similar to find_matches can write it better...
    filter = Filter.new
    
    filter.search_by = "likes"
    filter.get_sample = false
    users = filter.get_scope(self.id)
    #users = users.sample(LikeMeConfig::maximal_matches) #to make it run faster #gets the array
    my_pages = self.user_page_relationships.group_by(&:relationship_type) #hash: key=type, value=array of pages
    @@all_page_aliases.each {|t|  my_pages[t] ||= []  } 
   
    user_type_scores = Hash.new
    users_scores = Hash.new
    
    results = []
    users.each do |user| 
      user_pages = user.user_page_relationships.group_by(&:relationship_type)
      if user_pages.blank?
        user_type_scores = [0.0]
      else
        user_type_scores = user_pages.map do |type, page_array| #error if no likes
          next if (@@weights[type] == 0 )
          begin        
            my_score = ((my_pages[type].map(&:page_id) & user_pages['l'].map(&:page_id)).count.to_f)/(my_pages[type].count + 1)
          rescue
            my_score = 0
          end
          begin
            user_score = ((user_pages[type].map(&:page_id) & my_pages['l'].map(&:page_id)).count.to_f)/(user_pages[type].count + 1)
          rescue
            my_score = 0
          end
          score = ((my_score+user_score) / 2.0) * @@weights[type].to_f
          score  
        end
      end
      
      user_type_scores.compact!
      user_total_score = user_type_scores.inject{ |sum, el| sum + el }.to_f / user_type_scores.size
      user_chosen_likes = []
      begin
      user_chosen_likes = user_pages[get_char(filter.search_by)].sample(6).map(&:page_id) #choose whet type pf likes to show
      rescue
      end
      user_total_score = (user_total_score/(6-user_chosen_likes.size) - 0.000001*(6-user_chosen_likes.size)) if user_chosen_likes.size<6 #don't want them in the top 5
      users_scores[user.id] = [user.id,user_total_score]
      results << [user.id, user_total_score]
    end
    results.each do |score_array|
      users_scores[score_array[0]] = [score_array[1],score_array[2]]
    end
    users = users.to_a.sort_by {|user| users_scores[user["id"]][0]*(-1)}
    users_scores = users_scores.sort_by { |id, score| score[0]*(-1) }
    
    score_array = []
    my_id = self.id
    users_scores.each do |user_score|
      score_array << Score.new(:user_id => my_id, :friend_id => user_score[0], :category => "l", :score => user_score[1][0])
    end
    
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("DELETE FROM scores WHERE user_id = #{self.id}")
      Score.import score_array   
    end

    
  end   
=end
=begin
  def get_excluded_users_id_array(filter)
    scores = Score.where(:user_id => self.id, :category => get_char(filter.search_by)).order("score")
    if scores.count > 25
      users = scores.first(scores.count - 25).map(&:friend_id)
    else
      users = []
    end
  end
  
  def get_likes_to_precalculated_scores(users_id,filter)
    #I need an hash where every user_id go to [score,likes] 
    filter.excluded_users = []
    filter.include_only = users_id
    users = filter.get_scope(self.id)
    
    users_order = users.order("score").first(25)
    users = User.where(:id => users_order)
    if self.search_by == 'likes'
      users = users.includes(:user_page_relationships)
    else
      users = users.includes(:user_page_relationships).where("user_page_relationships.relationship_type = ? OR user_page_relationships.relationship_type = ?",get_char(self.search_by),'l')
    end
    
  end 
=end
=begin
  def find_matches_old(filter)  #main matching algorithm, returns sorted hash of {id => score}

    #excluded_users_id_array = get_excluded_users_id_array(filter)
    #filter.excluded_users = Score.where(:user_id => self.id, :category => get_char(filter.search_by)).map(&:friend_id)
    #filter.included_users = Score.where(:user_id => self.id, :category => get_char(filter.search_by)).order("score").last(LikeMeConfig::number_of_precalculated_users).map(&:friend_id)
    #filter.set_users(self.id)
    users = filter.get_scope(self.id) 
    #raise users.all.to_s
       
    my_pages = self.user_page_relationships.group_by(&:relationship_type) #hash: key=type, value=array of pages
    @@all_page_aliases.each {|t|  my_pages[t] ||= []  } 
   
    user_type_scores = []
    users_scores = Hash.new
    

    results = Parallel.map(users, :in_processes=>LikeMeConfig::matching_cores) do |user| #have user groups here for parallel include
      #shared_pages_id = [] 
      user_pages = user.user_page_relationships.group_by(&:relationship_type)
      shared_pages_id = []
      if user_pages.blank?
        user_type_scores = [0.0]
      else
        user_type_scores = []
        user_pages.map do |type, page_array| #error if no likes
          next if (filter.weights[type] == 0 ) #todo change here!

          my_pages[type] = [] if my_pages[type].empty? 
          user_pages['l'] = [] if user_pages['l'].empty? 
          my_shared_pages_id = my_pages[type].map(&:page_id) & user_pages['l'].map(&:page_id)
          my_score = (my_shared_pages_id.count.to_f)/(my_pages[type].count.to_f + 1)

          user_pages[type] = [] if user_pages[type].empty? 
          my_pages['l'] = [] if my_pages['l'].empty? 
          user_shared_pages_id = user_pages[type].map(&:page_id) & my_pages['l'].map(&:page_id)
          user_score = (user_shared_pages_id.count.to_f)/(user_pages[type].count.to_f + 1)
          
          shared_pages_id.push([my_shared_pages_id, user_shared_pages_id])
          score = ((my_score+user_score).to_f / 2.0) * filter.weights[type].to_f          
          user_type_scores.push(score)
        end
      end

      user_type_scores.compact!
      if user_type_scores.empty?
        user_total_score = 0.0
      else
        user_total_score = user_type_scores.inject{ |sum, el| sum + el }.to_f / user_type_scores.size
      end
      user_chosen_likes = []
      user_chosen_likes = shared_pages_id.flatten.uniq.shuffle
      user_chosen_likes.push(user_pages[get_char(filter.search_by)].sample(6).map(&:page_id)) unless user_pages[get_char(filter.search_by)].blank?
      user_chosen_likes = user_chosen_likes.flatten.uniq.first(6)
      #user_chosen_likes = user_pages[get_char(filter.search_by)].sample(6).map(&:page_id)
      
      user_total_score = (user_total_score/(6-user_chosen_likes.size) - 0.000001*(6-user_chosen_likes.size)) if user_chosen_likes.size<6 #don't want them in the top 5
      users_scores[user.id] = [user.id,user_total_score,user_chosen_likes]
    end
    #raise results.to_s  
    results.each do |score_array|
      users_scores[score_array[0]] = [score_array[1],score_array[2]]
    end
    
    users = users.to_a.sort_by {|user| users_scores[user["id"]][0]*(-1)}
    users_and_likes = []
    users.each do |user|
      users_and_likes << [user,users_scores[user.id][1]]
    end
    #raise users_and_likes.to_s
    #users_objects = User.where(:id => users_scores.keys).all already have it
    #raise users_scores.to_s
    users_scores = users_scores.sort_by { |id, score| score[0]*(-1) }
    #raise users_scores.to_s
    #users_order = users_scores.collect {|x| x[0]}.to_s
    #users_objects = User.where(:id => users_scores.keys)
    #return users_scores
    #raise users_and_likes.size.to_s
    #raise users_and_likes.to_s
    return users_and_likes
  end
=end
=begin
   def calculate_scores_old(filter) # similar to find_matches can write it better...
    #filter = Filter.new
    #filter.set_params({})
    #raise filter.search_by if filter.search_by=="music"
    category = filter.search_by
    filter.get_sample = false
    #filter.set_weights
    users = filter.get_scope(self.id)
    
    #filter.search_by = category
    
    #users = filter.get_scope(self.id)
    #users = users.sample(LikeMeConfig::maximal_matches) #to make it run faster #gets the array
    my_pages = self.user_page_relationships.group_by(&:relationship_type) #hash: key=type, value=array of pages
    @@all_page_aliases.each {|t|  my_pages[t] ||= []  } 
   
    user_type_scores = []
    users_scores = Hash.new
    #raise filter.weights.to_s
    results = []
    users.each do |user| 
      user_pages = user.user_page_relationships.group_by(&:relationship_type)
      #raise user_pages.to_s if user.id = 4812944 && category == "music" 
      if user_pages.blank?
        user_type_scores = [0.0]
        #raise user_pages.to_s if user.id = 100003977536148
      else
        user_type_scores = []
        user_pages.map do |type, page_array| #error if no likes
          #raise filter.weights.to_s
          next if (filter.weights[type] == 0 ) #todo change here!
          #raise filter.weights.to_s if user.id = 4812944 && category == "music"
          my_pages[type] = [] if my_pages[type].empty? 
          user_pages['l'] = [] if user_pages['l'].empty? 
          my_shared_pages_id = my_pages[type].map(&:page_id) & user_pages['l'].map(&:page_id)
          my_score = (my_shared_pages_id.count.to_f)/(my_pages[type].count.to_f + 1)

          user_pages[type] = [] if user_pages[type].empty? 
          my_pages['l'] = [] if my_pages['l'].empty? 
          user_shared_pages_id = user_pages[type].map(&:page_id) & my_pages['l'].map(&:page_id)
          user_score = (user_shared_pages_id.count.to_f)/(user_pages[type].count.to_f + 1)
          
          score = ((my_score+user_score).to_f / 2.0) * filter.weights[type].to_f
          #raise category.to_s if user.id = 4812944 #&& category == "music"           
          user_type_scores.push(score)
        end
      end
      #raise user_type_scores.to_s if user.id = 100003977536148
      user_type_scores.compact!
      user_total_score = user_type_scores.inject{ |sum, el| sum + el }.to_f / user_type_scores.size unless user_type_scores.size == 0
      user_total_score = 0 if user_type_scores.size == 0
      user_chosen_likes = []
      begin
      user_chosen_likes = user_pages[get_char(filter.search_by)].sample(6).map(&:page_id) #choose whet type pf likes to show
      rescue
      end
      user_total_score = (user_total_score/(6-user_chosen_likes.size) - 0.000001*(6-user_chosen_likes.size)) if user_chosen_likes.size<6 #don't want them in the top 5
      #raise user_total_score.to_s if user.id = 4812944 && category == "music"
      users_scores[user.id] = [user.id,user_total_score]
      results << [user.id, user_total_score]
      #raise filter.weights.to_s if user.id = 4812944 && category == "music"
      #raise results.to_s if user.id = 4812944 && category == "music" #I got here with the right filter
    end
    #raise results.to_s if category == "music" #and here I have NaN
    results.each do |score_array|
      users_scores[score_array[0]] = score_array[1]
    end
    
    #users = users.to_a.sort_by {|user| users_scores[user["id"]][0]*(-1)}
    begin
    users_scores = users_scores.sort_by { |id, score| score*(-1) }
    rescue
      raise users_scores.to_s + "          " + category.to_s
    end
    #raise users_scores.to_s
    score_array = []
    my_id = self.id
    users_scores.each do |user_and_score|
      score_array << Score.new(:user_id => my_id, :friend_id => user_and_score[0], :category => get_char(category), :score => user_and_score[1])
    end
    #raise score_array.to_s
    ActiveRecord::Base.transaction do
      #todo WTF WTF WTF ActiveRecord::StatementInvalid: PGError: ERROR:  column "b" does not exist
      #ActiveRecord::Base.connection.execute("DELETE FROM scores WHERE user_id = #{self.id} AND category = #{get_char(category)};")
      Score.destroy_all(:user_id => self.id, :category => get_char(category))
      Score.import score_array   
    end
  end  
=end
    