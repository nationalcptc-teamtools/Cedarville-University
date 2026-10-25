To begin [[API Testing]], start by discovering its attack surface.

Identify API endpoints. These are the locations where an API receives requests about a specific resource on its server.
	ex. 
	GET /api/books HTTP/1.1
	Host: example.com

The API endpoint for this request is /api/books. This causes an interaction with the API to retrieve a list of books from a library. Another endpoint could be /api/books/mystery.

Continue identifying endpoints, as well as how to interact with them in order to construct valid HTTP requests.
	- The input data the API processes (compulsory and optional parameters)
	- Types of requests the API accepts, including supported HTTP methods and media formats
	- Rate limits and authentication mechanisms