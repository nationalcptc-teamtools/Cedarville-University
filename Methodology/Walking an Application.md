Having a process to enumerate an application can be helpful to make sure everything is covered thoroughly.

[[Dev Tools]] (Developer Tools) within a browser can be helpful at observing the contents and workings of a webpage.


Web servers also conventionally expose several files that may reveal more information than intended and help map the attack surface.
	robots.txt
		robots.txt tells search engine crawlers which pages they may index. Sensitive directories are often listed here to prevent them from appearing in search results.
	sitemap.xml
		sitemap.xml tells search engines which pages the owner *wants* listed. This file can include staging pages, old content, or directories that are difficult to reach from the normal site. These urls may also include parameters which indicate input points worth testing.

HTTP Headers
	Web server responses to requests include HTTP headers that can reveal technical details. Use the curl command with the option -v to enable verbose output, which includes response headers.

Framework Stack
	The framework of a website can be identified by the favicon, headers, or inspecting the page source for comments or copyright notices.
	Researching the framework through its own website can be very instructive. Documentation pages often include details about directory structures, admin panels, and default credentials.

---

OSINT (Open Source Intelligence) can also uncover more information about the target website.
	[[Google Dorking]] uses advanced search operators to filter results to discover sensitive content.
	--
	Wappalyzer is a browser extension that identifies the technologies used by a website, including frameworks, payment processors, analytics tools, and more. It can sometimes detect version numbers as well.
	--
	Wayback Machine is an archive of the internet as far back as the 1990s. It can be searched for individual domains, which shows every snapshot captured.
	This is useful for finding pages that may be still accessible, although removed from the live site, such as old login forms, forgotten API endpoints, or content which was available briefly before being taken down.
	--
	Git is a version control system that tracks changes over time. GitHub is the most widely used cloud-hosted platform for Git repositories. Sometimes sensitive data will be committed in public repos briefly, and can be recovered from the commit history.
	--
	Simple Storage Service (S3) is a cloud storage platform used to host files and static website content.
	URL format for an S3 bucket: https://{name}.s3.amazonaws.com
	Bucket permission misconfigurations are common. Check common naming patterns below, as well as searching GitHub repositories and the website's page source.
		{company}-assets
		{company}-backup
		{company}-www
		{company}-dev

---

Automated Discovery tools can be used to map a web server environment. This generally relies on [[Resources/Wordlists - GEN|Wordlists]].

One excellent automated discovery tool is [[Gobuster]].