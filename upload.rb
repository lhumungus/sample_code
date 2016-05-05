def self.slurp(params, autoscript = false)
	begin

		unless !params[:upload].blank? && !params[:upload][:upload_filename].blank?
			return false, "No file selected."
		end

		##  Limit upload size to 5MB
		# unless valid_file_size?(params[:upload][:upload_filename])
		# 	return false, "Maximum file size is 5MB"
		# end

		begin
			jobid = Digest::SHA1.hexdigest("#{params[:upload][:upload_filename]}_#{Time.new().to_f}")

			##  When this method is invoked via automated script, we pass the pathname of the input
	        	##    file directly
	        	if autoscript
	          		tmpfilename = params[:upload][:upload_filename]
			else
	      	  		tmpfilename = "/tmp/cati_infile_#{jobid}.csv"
	      	  		f = File.open(tmpfilename, "wb")
	      	  		f.write(params[:upload][:upload_filename].read)
	      	  		f.close
			end

			csvdata = CSV.read(tmpfilename, :headers => true, :return_headers => :true, :col_sep => ",", :row_sep => :auto)

	      		##  After successful readin, automatically delete the tmp file
	      		File.delete(tmpfilename)
		rescue
	      		return false, "Invalid file format: #{$!}."
		end


		##  REV 2015-11-16	New variables were added last week, SQUARE_FOOTAGE,BEDROOMS; these
		##  					will be used to calculate visit length
		##  NOTE:  we are creating customers AND appointments
		## Strata1	Strata2	CUSTOMER_FIRST_NAME	CUSTOMER_LAST_NAME	CONTACT_NAME_2	EE_ID	
		##  service address_ ZIP9	SERVICE_ADDRESS_STREET	SERVICE_ADDRESS_UNIT	SERVICE_ADDRESS_CITY	
		##  Primary_phone	Secondary_phone	Primary_Language	Updated_Address_C	
		##  Home_type_O	Home_type_reported 	Ownrent	HOME_POP	Seniors_inhome	KIDS_INHOME	
		##  Disposition	
		##  Primary_Backup	Date_SCHEDULED (DD_MM_YY)	Start_Time_SCHEDULED (24:00)	Schedule_Notes	Engineer_Name	
		##  ENTHUSIASM1	ENTHUSIASM2	DATE_CALL_BACK	TIME_CALL_BACK	GIVEN_PHONE	GIVEN_EMAIL
		read_count = 0
		import_count = 0
		skip_it = 1
		csvdata.each do |row|
			unless row.header_row?
				##  Dataset comes with extra header line, so ignore first line after header
				# unless skip_it == 0
				# 	skip_it = 0
				# 	next
				# end


			  	read_count += 1
			  	customer = Customer.find(:first, :conditions => "ee_id = '#{row['EE_ID']}' ")
		      	  
				##  REV 2016-03-17	If an incoming record includes 'MU' in the strata, we will update
				##  					its appointment and customer info.  Otherwise, incoming records that match
				##  					existing records will be ignored.
				##  Only proceed with import if it's a new customer, or has MU in strata02,  and EE_ID IS NOT BLANK <<<<
				if ( customer.blank? && !row['EE_ID'].blank? ) 
		      	  	customer = Upload.create_new_customer(row)
		  	  		customer.save!
				  	puts "Importing new customer...done!"

				  	appointment = Upload.create_new_appt(customer, row)

				  	##  Assign engineer ID based on incoming name, which had better match
				  	##  If customer save succeeds but engineer is invalid, then delete customer
				  	if row['ENGINEER_NAME'] == 'Incorrect Name'
				  	  engineer = User.find(:first, :conditions => "CONCAT(firstname, ' ', lastname) = 'Engineer Name' ")
					else
				  	  engineer = User.find(:first, :conditions => "CONCAT(firstname, ' ', lastname) = '#{row['ENGINEER_NAME']}' ")
					end
				  	unless !engineer.blank?
				  		customer.delete
				  		raise "Engineer Name \'#{row['ENGINEER_NAME']}\' is not valid"
				  	end
				  	appointment.engineer_id = engineer.id

				  	##  If customer save succeeds but appointment fails, then delete customer
				  	begin
					  	appointment.save!
					rescue
				  		customer.delete
				  		raise "invalid appointment data:  #{$!}"
				  	end
				  	puts "Creating appointment...done!"


				elsif !customer.blank? && row['STRATA2'].index('MU')
		  	  		customer = Upload.update_customer(customer, row)
		  	  		customer.save!
				  	puts "Updating existing customer...done!"

				  	appointment = Upload.update_appt(customer, row)

				  	##  Assign engineer ID based on incoming name, which had better match
				  	##  If customer save succeeds but engineer is invalid, then ERROR OUT BUT DO NOT DELETE CUSTOMER
				  	if row['ENGINEER_NAME'] == 'Incorrect Name'
				  	  engineer = User.find(:first, :conditions => "CONCAT(firstname, ' ', lastname) = 'Engineer Name' ")
					else
				  	  engineer = User.find(:first, :conditions => "CONCAT(firstname, ' ', lastname) = '#{row['ENGINEER_NAME']}' ")
					end
				  	unless !engineer.blank?
				  		raise "Engineer Name \'#{row['ENGINEER_NAME']}\' is not valid.  CUSTOMER RECORD UPDATED BUT APPT HAS BEEN IGNORED."
				  	end
				  	appointment.engineer_id = engineer.id


				  	##  If customer save succeeds but appointment fails, then ERROR OUT BUT DO NOT DELETE CUSTOMER
				  	begin
					  	appointment.save!
					rescue
				  		raise "invalid appointment data:  #{$!}.  CUSTOMER RECORD UPDATED BUT APPT HAS BEEN IGNORED."
				  	end
				  	puts "Updating appointment...done!"

				end

				import_count += 1
		    end
		end

	    ##  Track count of records imported, and report back
		return true, "Read #{read_count.to_i} records. Imported <b style='font-weight:bold;'>#{import_count.to_i}</b> records successfully.".html_safe
	rescue
		return false, $!.to_s + ", line #{read_count}."
	end
end
