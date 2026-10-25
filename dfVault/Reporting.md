
"A report will never ever ever ever ever ever be personal. Never I, me, we. An analyst discovered...After the team examined..." - Nick Sheldon

A pentest report should flow like a narrative - it should be easy to follow from section to section


Executive Summary - summary of the full report for non-technical people. Should be completely nontechnical. Not more than 2 pages long. (Who you are and what you did.)
	"For the business majors who don't know the difference between a red and blue crayon." - Nick Sheldon
	Summary of Findings
		Number of vulnerabilities, etc
	Key Strengths
		What was good in terms of security.
	Key Weaknesses
		What was bad in terms of security.
	Prioritized for Remediation
		Rank remediation

Introduction
	Include brief summary (slightly more technical than Executive Summary)
	Scope and what was given to test / Testing Artifacts
		Scope should explicitly state was is in scope
	Methodology
		High level of activity with some slight technical explanation

Findings
	Listing of findings. How were the findings scored? (CVSS 4.0)
	Table of findings (summary of all findings in a table and ranked)
	Every finding (has a box) should start a new page, not matter how little of the page is used
	Finding box
		- Use the CVSS string in each report
		- Impact is the Classification from CVSS
		- Risk is from our own metric
		- Include Business Impact ("Business majors think of two things - crayons and money" - Nick Sheldon)
		- Impacted artifacts and Vulnerability Description should be present as well - show where the problem is, why it's there and how to fix it.
		- CWE - common weakness enumeration
		- Technical Analysis

Narrative
	- Your thought process on a piece of paper; all your steps and screenshots
	- Should be the longest section
	- The audience should be able to recreate the entire findings section from just the narrative. This should be as detailed as possible
	- Don't get too detailed into the recommended remediations - must remain unbiased
	- Narrative and Methodology sections are largely the same



Related notes
---

- [[Flat Images - GEN|Flat Images]]
