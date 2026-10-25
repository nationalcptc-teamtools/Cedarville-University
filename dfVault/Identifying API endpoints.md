Interacting with identified API endpoints with [[Tools/GUI Tools/Burp Repeater - GEN|Burp Repeater]] and [[Tools/GUI Tools/Burp Intruder - GEN|Burp Intruder]] can yield information about the API's behavior and uncover additional attack surface.

API error messages and responses can leak the necessary information to construct a valid HTTP request.

API endpoints may support different [[Protocols and Notation/HTTP - GEN|HTTP]] methods, such as GET, PATCH, or OPTIONS

Test all potential methods to identify the full endpoint functionality. [[Tools/GUI Tools/Burp Intruder - GEN|Burp Intruder]] includes a built in HTTP verbs lit to cycle through a range of methods.

Supported Content Types
	API endpoints often expect data in a specific format. They may behave differently depending on the content type of data provided in a request.
	Modifying the Content-Type header (and reformatting the request body) may
		- trigger errors that disclose useful information
		- bypass flawed defenses
		- take advantage of differences in processing logic
	Use the Content type converter BApp to convert data between XML and JSON

With an initial list of API endpoints, [[Tools/GUI Tools/Burp Intruder - GEN|Burp Intruder]] can uncover hidden endpoints by identifying other resources with the same structure.

Use wordlists of common API naming conventions when looking for hidden endpoints.