[[API Reconnaissance]] may uncover supported and undocumented parameters that could be used to change the application's behavior.

[[Tools/GUI Tools/Burp Intruder - GEN|Burp Intruder]] allows for automatic discovery of hidden parameters

Param miner BApp enables automatic guessing of application-relevant parameter names based on information taken from the scope.

The Content Discovery tool enables discovery of content that isn't linked to visibly browsable content, including parameters.

Mass assignment (auto-binding) can inadvertently create hidden parameters.
	When software frameworks automatically bind request parameters to fields on an internal object.
Mass assignment may result in the application supporting parameters that were never intended to be processed by the developer.

Identifying Hidden Parameters
	manually examine objects returned by the API
	ex. PATCH /api/users/
	includes JSON
		{
			"username": "example",
			"email": "example@email.com",
		}
	GET /api/users/123 returns
		{
			"id": 123,
			"name": "John Doe",
			"email": "john@example.com",
			"isAdmin": "false"
		}
	This may indicate that the hidden id and isAdmin parameters are bound to the internal user object

Testing mass assignment vulnerabilities
	To test modifying the enumerated parameter value, add it to the PATCH request. Send a PATCH request with an invalid isAdmin parameter value.
	If the application behaves differently, it is possible the invalid value impacts query logic, but the valid value does not. This may indicate the user can successfully update the parameter.
	If the isAdmin value in an updated request is bound to the user object without adequate validation and sanitization may be incorrectly granted admin privileges.
