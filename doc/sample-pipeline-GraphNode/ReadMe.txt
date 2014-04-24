Sample pipeline using the RDF Pipeline Framework
================================================

To run this pipeline after installing the RDF Pipeline Framework:

0. These commands must be run as root, so start a root shell:

  sudo bash

1.  Copy the content of the www subdirectory into apache2's
$DOCUMENT_ROOT directory, which may be /var/www:

  cd sample-pipeline
  cp -rp www/* /var/www

2. Change ownership to the apache2 user (often www-data):

  . /etc/apache2/envvars
  chown -R "$APACHE_RUN_USER":"$APACHE_RUN_GROUP" /var/www
  
3. Restart apache2: 

  service apache2 restart

4. Exit the root shell:

  exit

5. Test the pipeline:

  curl http://localhost/node/willies

It should return output like this:

@@ TODO @@

6. Check the apache2 log for errors:

  tail -n 20 /var/log/apache2/error.log


