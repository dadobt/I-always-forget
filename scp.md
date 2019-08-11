To copy all from **Local Location** to **Remote Location** (Upload)

``sh
scp -r /path/from/destination username@hostname:/path/to/destination
``

To copy all from **Remote Location** to **Local Location** (Download)

``sh 
scp -r username@hostname:/path/from/destination /path/to/destination
``

Custom Port where ``sh xxxx `` is **custom port** number

``sh
 scp -r -P xxxx username@hostname:/path/from/destination /path/to/destination
``

Copy on current directory from **Remote to Local**

``sh
scp -r username@hostname:/path/from/file .
``

**Help:** 


1. ``sh -r `` Recursively copy all directories and files
2. Always use full location from ``sh / ``, Get full location by ``sh pwd ``
3. ``sh scp`` will replace all existing files
4. ``hostname`` will be hostname or IP address
5. if custom port is needed (besides port 22) use ``sh -P portnumber``
6. **.(dot)** - it means current working directory, So download/copy from server and paste here only.


Note: Sometimes the custom port will not work due to the port not being allowed in the firewall, 
so make sure that custom port is allowed in the firewall for incoming and outgoing connection

