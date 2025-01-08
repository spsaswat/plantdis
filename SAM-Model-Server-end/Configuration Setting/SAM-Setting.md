This document explains the process of creating the Docker container of the Flask application and the server as well as how to expose the server port to the network through Apache. The SAM folder is the whole demo Flask application which deployed a Segment Anything model on the server.

# 1. SAM
The SAM directory contains our entire Flask application for segmentation. With this flask application, we can segment objects in any images. The bounding box can be drawn online or sent from the mobile end.
We use the pre-trained checkpoint which is too large to upload, please install the configuration file from this link: 
`https://github.com/facebookresearch/segment-anything`
![我的图片](./1.jpg)
And make sure to put this file in the SAM directory.


# 2. Docker Part Set Up

## Install the docker
`https://docs.docker.com/desktop/setup/install/windows-install/`
`https://docs.docker.com/desktop/setup/install/mac-install/`

## Building a Docker Image 
Go to the SAM directory, and run the following command (you can choose any server name as you like):
`docker build -t plantdis-sam-server .`

## Running a Docker Container
Create a container from previous image and run it on 8000 local port
`docker run -d -p 8000:5000 plantdis-sam-server`

Now you should be able to view the server content at your http://localhost:8000.

# 3. Apache Part Set Up
Then, what we are going to do is make the Apache find the localhost 8000 and make it expose to the local network, the step is called __Reverse Proxy__.

## Install the Apache

## Create and Run Apache Container
First, pull the Apache image and start it:
`docker pull httpd`
Then run the Apache container, exposing port 8080 on the host machine:
`docker run -d -p 8080:80 --name my_apache_container httpd`

## Edit the Apache Configuration File to Allow Reverse Proxy
Copy the .conf file to the path you want:
`docker cp my_apache_container:/usr/local/apache2/conf/httpd.conf /yourwanted/path/httpd.conf`

Then, find and uncommend the following configuration lines:

LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so

And add the following configuration at the end of the .conf file:

```apache
<VirtualHost *:80>
    ServerName localhost

    # Proxy all requests to the host machine's 8000 port (or other port else)
    ProxyPass / http://host.docker.internal:8000/
    ProxyPassReverse / http://host.docker.internal:8000/
</VirtualHost>
```

Or you may directly use the httpd.conf file within this folder.

Finally, copy the .conf back to the apache container:
`docker cp /yourwanted/path/httpd.conf my_apache_container:/usr/local/apache2/conf/httpd.conf`

## Restart Apache to Enable Changes
`docker exec -it my_apache_container apachectl restart`

## Then It Should Work!
See at http://[host_machine_LAN_IP]:8080 within the local network!
If you don't know your host machine LAN IP, you can type this at the terminal and find the IP (you should seerch at Env0 part and be careful!) :
`ifconfig`





