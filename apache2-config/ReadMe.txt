
Configuring Apache for RDF Pipeline Framework
=============================================

1. For the moment, Apache needs to run under user dbooth to allow
the RDF Pipeline framework to read/write to directories that
are owned by dbooth.  This is accomplished in envvars -- see
step 2 -- and by changing ownership of the apache lock directory.
To change ownership of /var/lock/apache2:

  # chown dbooth:dbooth /var/lock/apache2

2. Set up Apache configuration files:

	000-default	-- Loads mod_perl2 and RDF Pipeline framework.  
			Lives in
			/etc/apache2/sites-available but symbolically
			linked from /etc/apache2/sites-enabled .

	envvars		-- Sets user and group for RDF Pipeline framework.
			Lives in /etc/apache2/sites-available .

	ports.conf	-- Sets listening port for apache2.
			Important to set to limit access to localhost.
			Lives in /etc/apache2/sites-available .

See the associated examples of these files in this directory.

More notes:

000-default is an Apache2 configuration file for the RDF
Pipeline framework.  Under Ubuntu 10.04 it lives at
/etc/apache2/sites-enabled (and owned by root).  The location may differ
under other operating systems.   

You will need to modify the contents of 000-default to run
the RDF Pipeline Framework.  To see what portions should be
modified, compare it to 000-default.old to see what lines I (dbooth)
changed to enable it on my system.  Actually, I think I goofed
and clobbered the .old file, as it does not seem to be the original.

Note also that other applications may be using this configuration file
as well, so you should be careful not to mess them up.

WARNING: Do not create an extra .old file in /etc/apache2/sites-enabled ,
as *every* file in that directory seems to be read as a configuration file.
http://www.debian-administration.org/articles/412

I learned later that the sites-enabled directory should only contain
symbolic links to configuration files that actually live and remain
in the sites-available directory.  Apache does it this way so that
you can quickly enable or disable sites just by changing the
symbolic links.
 
