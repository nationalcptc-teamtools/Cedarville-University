*Red Team Tradecraft 9/24/26*
OWASP Juice Shop: `10.40.69.129:3000`
186 vulnerabilities
append `/#/score-board` for scoreboard

### Pentesting Methodology
MITRE ATT&CK Framework
- Enumeration
- Exploitation
- Privilege escalation

What is the first thing to do?
1. Use the application, look for domains, endpoints, credentials (emails), reviews
2. Register an account if possible. The website will likely act different if you are logged in. Continue to use the application

Web app pentest - look at `/robots.txt` - shows what they are hiding from automated web-crawlers, which is generally followed by **spiders** aka crawlers or bots

`/ftp` to find all the files, opened `acquisitions.md`

### Extensions
#### JWT Editor
- Signature will verify if certificate if JSON Web Token (JWT) is legit
- Common cookie format: header, content, signature
- Tokens are not always complete
#### MCP Server

#### Autorize
- take every single time you log into web app
- take your cookie and try different endpoints to see if your cookie can get into other user's webpage
- Good for CSRF
##### Dependency
Extension type language called `Jython`
- Burp Suite is created using Java, lot of extensions are created using Python
- will need to install `jython-installer-2.7.4.jar` or later version (not beta with `b` in the name) from [Jython Website](https://www.jython.org/) to Downloads and run it, saving the output file location to somewhere that won't get deleted
	- Add it to `Settings` (gear icon in top right) -> `Extensions` -> `Core extension settings` -> `Python environment` -> `Location of Jython standalone JAR file:`
- Error should go away (same with BApp error if you used the installer method and not just the JAR file), install `Autorize`

### Using Burp Suite
*Disclaimer: Can't save projects without Professional Edition and Professional License*
1. Turn on Burp Suite on FoxyProxy (browser extension)
2. Toggle Proxy -> `Intercept on` in Burp Suite
3. FoxyProxy will return a lot of extra websites that we don't want instead of using `Proxy` -> `Open Browser` button which opens a browser that already has the proxy integrated instead of FoxyProxy
	- need to right-click on line we do want -> `Add to scope`
		- may need to do this in `Target` -> `Site map` -> `<website_domain>` instead
	- Go to `Proxy settings` -> request interception rules -> check the "and URL is in target scope" box, add it if not there
	- This will filter to only the websites/domains that we do want
4. `Forward` button allows the request to continue onto the server, `Drop` drops the packet from continuing and an error message is displayed on the website
	- Burp Suite captures the request from the client and holds until it forwards it to the server, and can also be used to capture the server response coming back

#### Right-Clicking on Entry
- right-clicking on any entry gives us many options
	- Add to scope
	- Send to Intruder/Repeater/Sequencer/Organizer/Comparer (request or response) which allows for manipulation before sending
	- Can open it in `Extensions`
	- **When currently intercepting**, can see `Do intercept` -> `Response to this request` to capture the server response after forwarding it

### Menus
#### `Target`
- shows `Site map` and `Scope`
- `Scope` shows all the entries in the current scope
- `Site map` shows the `Inspector` tool on a specific request and response pairs to see different values and formats

#### `Proxy`
- `Intercept` - for intercepting, forwarding, and dropping web requests
- shows `HTTP history` - helpful for finding requests that have already been forwarded to reinspect them

#### `Intruder`
- can open multiple tabs
- can run various attacks against the website using payloads
	- the `Add $` button adds the highlighted text beneath it as a payload position, also `Clear $` and `Auto $`
- Edit wordlist to be used for a payload position using the `Payload configuration` section
	- Can `Paste` list from clipboard and split into 1 entry per line, `Load...` from a file (such as `rockyou.txt`), `Remove` selected items, `Clear` the wordlist, `Deduplicate` to remove duplicate entries so not to run unnecessary extra requests
- Define rules to use in `Payload processing` section
	- Adding rules to manipulate wordlist right before it is inserted into the request
	- Rules run in order from top to bottom
	- `Add` -> `Select rule type` dropdown gives a lot of self-explanatory ideas
- Start attack to run
##### Attacks
1. Sniper attack
	- inserts each payload into each position one at a time using a single payload set
	- Ex: `username` and `password` positions, will cycle through wordlist (specified by `payload configuration`) on `username` with `password` fixed, and then cycle through `password` with `username` fixed
2. Battering ram attack
	- simultaneously places the same payload into all positions using a single payload set
	- Ex: `username` and `password` both get set to `admin123`
3. Pitchfork attack
	- allocate a payload set for each position (multiple payload sets), and the intruder tab will iterate through each set in parallel
	- Ex: `username` has its own wordlist, `password` has its own wordlist, and item 1 of `username` wordlist is paired with item 1 of `password` wordlist and sent, same with both item 2s, item 3s, etc.
	- Best for correlated pairs of data, like usernames matched to their passwords
4. Cluster bomb attack
	- allocate a payload set to each position (multiple payload sets), and the intruder iterates through all possible combinations of each set
	- Ex: `username`'s wordlist has 100 items (specified in `Payload count`) and `password`'s wordlist has 100 items, then it will send 10,000 requests (specified in `Request count`)
	- Best for brute-forcing

#### `Repeater`
- manually manipulate and send requests to test and see the response on the other side
- helpful for tweaking requests by small amounts
- Can group requests together by right-clicking on any tab and making a group
	- helpful for using in the different group send options under the `Send` dropdown
	- `Send group in sequence (single connection)`
		- sends all requests from every tab in the group one after another in order over one persistent connection, then close
		- used to test for client-side desync vulnerabilities
	- `Send group in sequence (separate connections)`
		- sends all requests from every tab in the group one after another in order but with new connections for each request
		- helpful for replaying a multi-step flow
	- `Send group in parallel`
		- send all requests in the group at once
		- synchronized to land at the server **as close to simultaneously as possible** via last-byte synchronization (HTTP/1) or single-packet attack (HTTP/2)
			- last-byte synchronization holds back the final byte of each request until all connections are ready, then releases them all together
		- tests for **race conditions** on the server
			- the server checks a condition, then performs an action
			- the small pause between the condition and action can cause there to be a momentary state where the condition has not been changed
			- sending multiple requests at the exact same time can cause all of them to trigger the condition and perform the action repeatedly, such as sending money to a bank or using a promo code for financial gain
- `Inspector`
	- Allows you to easily change or add parameters and values to the request that you can see in the `Request` tab
	- `Request attributes` shows up in line 1: `GET...`
	- `Request query parameters` entered after `?` after the request attributes on the first line
	- `Request body parameters` entered in `Form=` at the bottom of the request
	- `Request cookies` specified at the bottom of the headers typically
	- Oftentimes, changing the preexisting `password` value to nothing or creating a request where `password` is empty can allow you to gain unauthorized access
	- `Request headers` for all other info