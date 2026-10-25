APIs are usually documented so that developers can use and interact with them.

Documentation has to be designed in both a human-readable and a machine-readable context.
	Human-readable - for developers to understand the API
	Machine-readable - to be processed by software for automating tasks like API integration and validation. Usually written in structured formats like [[Tools/Languages/JSON - GEN|JSON]] or [[Tools/Languages/XML - GEN|XML]].

API documentation is often publicly available, particularly if it is intended for use by external developers. If so, start [[API Reconnaissance]] by reviewing the documentation.

Even if the API documentation isn't publicly available, it may still be accessible through browsing applications that use the API.

[[Tools/GUI Tools/Burp Scanner - GEN|Burp Scanner]] can crawl the API to identify endpoints that may refer to API documentation.

Investigate the base path of all resource endpoints.
	ex. /api/swagger/v1/users/123
	investigate
		/api/swagger/v1
		/api/swagger
		/api

Automated tools can analyze any machine-readable API documentation.

[[Tools/GUI Tools/Burp Scanner - GEN|Burp Scanner]] can crawl and audit API documentation in a [[Tools/Languages/JSON - GEN|JSON]] or [[Tools/Languages/YAML - GEN|YAML]] format.

Other tools to test documented endpoints include [[Tools/GUI Tools/Postman - GEN|Postman]] and [[Tools/GUI Tools/SoapUI - GEN|SoapUI]]