
In Linux, each user is assigned a unique user ID wchich decides what permission and privilege the user has.

In [[Architecture/Unix - GEN|Unix]] systems, the user ID information is stored in the password file ([[Linux CLI Commands/etc-passwd - GEN|/etc/passwd]]). This is an example entry for root:

root:x:0:0:root:/root:/bin/bash

The first field is the user or account name. The third field is the user ID assigned to the user.

When a user logs into an account, the operating system creates an initial process for the user and the user ID of the process is set using the third field. Child processes inherit this user ID. Whenever a process tries to access a resource, the operating system checks the user ID (and some other privilege information) to determine if access should be granted.

The command [[Linux CLI Commands/id - GEN|id]] prints the user and group IDs.

In [[Architecture/Unix - GEN|Unix]] operating systems, root is a special user because of its user ID. Root has a user ID of 0, which gives it privilege.

Inside the operating system, many of the access controls check whether the user ID is zero, and if it is, grant automatic access.

To add a user there are several options
- add a new user record in [[Linux CLI Commands/etc-passwd - GEN|/etc/passwd]] and [[Linux CLI Commands/etc-shadow - GEN|/etc/shadow]]
- use the [[Linux CLI Commands/adduser - GEN|adduser]] command (higher level tool compared to [[Linux CLI Commands/useradd - GEN|useradd]])

To temporarily switch to another user account, use the command [[Linux CLI Commands/su - GEN|su]]
