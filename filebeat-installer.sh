name="World"
#echo "Hello $name!"

get_test(){
	echo "Hello World - Test"
}

get_publicSign(){
	echo "Adding the Public Signing Key"
	sudo rpm --import https://packages.elastic.co/GPG-KEY-elasticsearch
	echo "Public Signing Key Added"
}


add_repoExtension(){
	echo "Starting Repo Addition"
	rm -rf /etc/yum.repos.d/logstash.repo
	echo -e "[elastic-8.x]\nname=Elastic repository for 8.x packages\nbaseurl=https://artifacts.elastic.co/packages/8.x/yum\ngpgcheck=1\ngpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch\nenabled=1\nautorefresh=1\ntype=rpm-md" >> /etc/yum.repos.d/logstash.repo
	echo "File Contents Saved Are:"
	cat /etc/yum.repos.d/logstash.repo
	echo "Repo Added"
}

install_fileBeat(){
	echo "Starting FileBeat Installation"
	sudo yum install filebeat -y
}


generate_rawCertificates(){
	read -p 'Enter the IP of the Logstash Server: ' logstashIP
	read -p 'Enter Log File Path [Full Path start with "/"]' logPath

	wget "https://raw.githubusercontent.com/iKunj/filebeat-support/main/client.conf"
	wget "https://raw.githubusercontent.com/iKunj/filebeat-support/main/server.conf"
	wget "https://raw.githubusercontent.com/iKunj/filebeat-support/main/filebeat.yml"

	sed -i "s/localhost:5044/$logstashIP:5044/" filebeat.yml
	sed -i "s/localhost/$logstashIP/" server.conf
	sed -i "s+filepathreplace+$logPath+" filebeat.yml

	openssl genrsa -out ca.key 2048
	openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt
	openssl genrsa -out server.key 2048
	openssl req -sha512 -new -key server.key -out server.csr -config server.conf
	openssl x509 -noout -serial -in ca.crt | cut -d'=' -f2 >> serial
	openssl x509 -days 3650 -req -sha512 -in server.csr -CAserial serial -CA ca.crt -CAkey ca.key -out server.crt -extensions v3_req -extfile server.conf
	mv server.key server.key.pem && openssl pkcs8 -in server.key.pem -topk8 -nocrypt -out server.key
	openssl genrsa -out client.key 2048
	openssl req -sha512 -new -key client.key -out client.csr -config client.conf
	openssl x509 -days 3650 -req -sha512 -in client.csr -CAserial serial -CA ca.crt -CAkey ca.key -out client.crt -extensions v3_req -extensions usr_cert  -extfile client.conf
}

copy_rawCertificates(){
	mkdir /etc/pki/logstash
	mkdir /etc/pki/filebeat
	cp ca.crt /etc/pki/logstash/
	cp server.key /etc/pki/logstash/
	cp server.crt /etc/pki/logstash/
	cp ca.crt /etc/pki/filebeat/
	cp client.key /etc/pki/filebeat/
	cp client.crt /etc/pki/filebeat/
	#cp filebeat.yml /etc/filebeat/
}

generate_SSL(){
	read -p 'Do you have SSL certificates [y/n]:' hasSSL
	if [[ $hasSSL == y || $hasSSL == Y ]]
	then
		echo "You have certificate"
		echo -e "\n\nPlease move the certificates to appropriate folders"
		exit 0
	else
		echo "Generating New Certificates"
		echo "$(generate_rawCertificates)"
		echo -e "\n\n\nRAW Certificates Generated Successfully"
		read -p 'Do You want to copy the files [This operation will create new folders] [y/n]:' hasCopy
		if [[ $hasCopy == y ]]
		then
			echo "Copying Certificates"
			echo "$(copy_rawCertificates)"
			echo "Copied Successfully"
		else
			echo "Scripted Finished"
		fi
	fi
}


generate_fbConfig(){
	read -p 'Enter Log File Path(Full Path): ' filepathfull
	#read -p 'Enter Logstash Server IP: ' hostip
	rm -rf filebeat.yml
	echo -e "filebeat.inputs:\n- type: log\n  id: my-log-id\n  enabled: true\n  paths:\n    - $filepathfull\n\nfilebeat.config.modules:\n  path: ${path.config}/modules.d/*.yml\n  reload.enabled: false\n\noutput.logstash\n  hosts: \['$hostip:5044'\]" >> filebeat.yml
	cat filebeat.yml
}

echo "Starting Installation"

read -p 'Full Install [Generates Certificates]/ Partial Install [Only Filebeat] [F/P]: ' insChar

if [[ $insChar == F || $insChar == f ]]
then
	echo "$(get_publicSign)"

	echo "$(add_repoExtension)"

	echo "$(install_fileBeat)"

	if [[ $? == 0 ]]
	then
		#cp filebeat.yml /etc/filebeat/
		echo -e "\n\nStating the Filebeat"
		#systemctl enable filebeat
		#systemctl start filebeat

		#echo -e "\n\nCheck the Status"
		#systemctl status filebeat

		echo "$(generate_SSL)"

		#TODO
		#echo "$(generate_fbConfig)"

		echo -e "\n\n\nFinalizing the Process"
		systemctl restart filebeat
		echo -e "Scripted Finished"
	else
		echo -e "\n\n\nInstallation Failed"
		exit 0
	fi
else
	echo "$(get_publicSign)"

	echo "$(add_repoExtension)"

	echo "$(install_fileBeat)"

	if [[ $? == 0 ]]
	then
		#cp filebeat.yml /etc/filebeat/
		echo -e "\n\nStating the Filebeat"
		#systemctl enable filebeat
		#systemctl start filebeat

		read -p 'Enter the IP of the Logstash Server: ' logstashIP
		read -p 'Enter Log File Path [Full Path start with "/"]' logPath

		#wget "https://raw.githubusercontent.com/iKunj/filebeat-support/main/client.conf"
		#wget "https://raw.githubusercontent.com/iKunj/filebeat-support/main/server.conf"
		#wget "https://raw.githubusercontent.com/iKunj/filebeat-support/main/filebeat.yml"

		#sed -i "s/localhost:5044/$logstashIP:5044/" filebeat.yml
		#sed -i "s/localhost/$logstashIP/" server.conf
		#sed -i "s+filepathreplace+$logPath+" filebeat.yml
		#cp filebeat.yml /etc/filebeat/

		echo -e "\n\n\nInstallation Completed"
		echo -e "\nCopy relevant files to these locations"
		echo 'client.crt => /etc/pki/filebeat/'
		echo 'client.key => /etc/pki/filebeat/'
		echo 'ca.crt => /etc/pki/filebeat/'
		echo "Installation Finished"
	else
		echo -e "\n\n\nInstallation Failed"
		exit 0
	fi
fi
