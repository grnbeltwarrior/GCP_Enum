#!/bin/bash

# Requirements:
#	  Google Cloud SDK: https://cloud.google.com/sdk/docs/install
# Created by GrnBeltWarrior
# Last Update: March 8th, 2021

function query() {
	# Get the organization:
	org="gcloud organizations list"
	org_id=$(/bin/bash -c "$org 2>/dev/null | grep -v ID | tr -s '[:blank:]' ',' | cut -d ',' -f 2")
	if [ "$org_id" != "" ]; then
		printf "\e[1;42m The organization id is: $org_id \e[0m\n"
		# Get the folders for the organization:
		folders=$(/bin/bash -c "gcloud resource-manager folders list --organization=$org_id | cut -d ' ' -f 1")
		for i in $folders; do
			if [ $i != "DISPLAY_NAME" ]
			then
				echo "Folder found:" $i
			fi
		done
		echo "Organizational level org-policies:"
		# Get the org-policies, at the org level:
		/bin/bash -c "gcloud resource-manager org-policies list --organization=$org_id 2>/dev/null"
	else
		printf "No organizational ID found, skipping enumeration requiring the org id.\n"
	fi
	# Get the list of projects:
	project_list=$(/bin/bash -c "gcloud projects list | cut -d ' ' -f 1")
	for n in $project_list; do
		not_tripped=0
		if [ $n != "PROJECT_ID" ]
		then
			# Bucketlist Output file
			destdir="$n.bucketlisting.txt"
			# Get a list of org-policies at the Project level, lists those not inherited from the Org:	
			org_pol=$(/bin/bash -c "gcloud resource-manager org-policies list --project=$n 2>/dev/null")
			if [[ "$org_pol" != "" ]]; then
				echo "Constraint assignment list for:" $n
				echo $org_pol | cut -d ' ' -f 1,2,3,4
				echo $org_pol | cut -d ' ' -f 5,6,7,8
			else
				not_tripped=$((not_tripped+1))
			fi
			# Get a list of service accounts for the project:
			service_accounts=$(/bin/bash -c "gcloud iam service-accounts list --project=$n 2>/dev/null")
			if [ "$service_accounts" != "" ]; then
				echo "Service Accounts for project:" $n
				printf "$service_accounts\n"
			else
				not_tripped=$((not_tripped+1))
			fi
			# List the buckets for each project:
			gsutil_result=$(/bin/bash -c "gsutil ls -p $n" 2>/dev/null)
			if [ "$gsutil_result" != "" ]; then
				echo "Bucket listing for project:" $n
				printf "\e[1;32m$gsutil_result \e[0m\n"
				# Recursively list the contents of the buckets:
				result=$(/bin/bash -c "gsutil ls -r -p $n gs://*")
				#printf "$result\n"
				echo "$result" >> $destdir
			else
				not_tripped=$((not_tripped+1))
			fi
			# List Compute Instances:
			dest_compute="$n.compute_instance_desc.txt"
			compute_instances=$(/bin/bash -c "gcloud compute instances list --project=$n 2>/dev/null | cut -d ' ' -f 1")
			if [ "$compute_instances" != "" ]; then
				for i in $compute_instances; do
					# Get the compute instance name:
					if [ "$i" != "NAME" ]; then
						# Describe Compute Instance:
						compute_desc=$(/bin/bash -c "gcloud compute instances describe $i")
						#printf "$compute_desc"
						echo "$compute_desc" >> $dest_compute
					fi
				done
			fi
			# List SQL:
			printf "List of SQL instances:\n"
			/bin/bash -c "gcloud sql instances list 2>/dev/null"
			# List Other Table/Data instances: TBD
			if [ $not_tripped == 3 ]; then
				printf "\e[1;31m$n: no custom constraints, listable service accounts or listable buckets.\e[0m\n"
			fi
		fi
		read -t 5
	done
	exit 0
}

# checks for authentication, using print-access-token from gcloud
# if the check fails (not authenticated) then you will be prompted to login.
authenticated=false
token=$(/bin/bash -c "gcloud auth print-access-token")

if [ "$token" != "" ]
then
	authentication=true
	printf "Already authenticated: $token\n"
	query
else
	/bin/bash -c "gcloud auth login"
	token=$(/bin/bash -c "gcloud auth print-access-token")
	printf "Authentication achieved: $token\n"
	query
fi
