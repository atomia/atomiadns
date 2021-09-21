## atomiadns-bindsync installation process.

BIND server has to be installed on Ubuntu 16/18 or CentOS/Redhat 7.

#### PRECONDITIONS
 For both Ubuntu and CentOS: BIND server needs to be installed.
 
#### INSTALLATION

##### Ubuntu

1. Set the appropriate repository.
2. Execute the command: *apt-get update*.
3. Execute the command: *apt-get install atomiadns-bindsync*.
4. Set manually:
	1. In *named.conf.local*:
		``` 
		include "/etc/bind/slave/named-slavezones.conf.local";
		```
	2. In *atomiadns.conf*:
		```
		slavezones_dir = /etc/bind/slave/zones
		slavezones_config = /etc/bind/slave/named-slavezones.conf.local
		rndc_path = /usr/sbin/rndc
		#ubuntu
		bind_user = bind
        ```
5. Execute the command: *Service atomiadns-bindsync restart*.
	
##### CentOS
	
1. Set the appropriate repository.
2. Execute the command: *yum install atomiadns-bindsync*.
3. Set manually:
	1. In *atomiadns.conf*:
		```
		bind_user = named
		```		
4. Execute the command: *Service atomiadns-bindsync restart*.
	
   