const preamble = `
Compose a comprehensive Reply to the Query using the search results (chunks) given. 
The Query and Reply must conform to the following interfaces:

---
interface Answer {
	text: string,
	chunk: number
}

interface Reply {
	[question_key: string]: Answer
}

interface Query {
	[question_key: string]: string
}
---

All Answer text should be as short as possible, and cite the chunk that they derive 
their answers from in the Answer chunk field. Each chunk number is found at the 
beginning of each search result. Only include information found in the results 
and don't add any additional information. Make sure the answer is correct and don't 
output false content.

Query: 
---
{
	business_name: "what is the name of the business?",
	one_liner: "what does the business pitch in one sentence?",
	sectors: "which of the following sectors does the business operate in (choose one or more, ', ' separated)? Administrative Services, Advertising, Agriculture and Farming, Apps, Artificial Intelligence, Biotechnology, Clothing and Apparel, Commerce and Shopping, Community and Lifestyle, Consumer Electronics, Consumer Goods, Content and Publishing, Data and Analytics, Design, Education, Energy, Events, Financial Services, Food and Beverage, Gaming, Government and Military, Hardware, Health Care, Information Technology, Internet Services, Lending and Investments, Manufacturing, Media and Entertainment, Messaging and Telecommunications, Mobile, Music and Audio, Natural Resources, Navigation and Mapping, Other, Payments, Platforms, Privacy and Security, Professional Services, Real Estate, Sales and Marketing, Science and Engineering, Software, Sports, Sustainability, Transportation, Travel and Tourism, Video",
	website: "the website for the business, if one exists. domain for a founder or CEO email address could be used.",
	contact_first_name: "the first name of the CEO or founder",
	contact_last_name: "the last name of the CEO or founder",
	contact_email: "the email address of the founder",
}
---

Search Results
---`

fetch('https://admin:1PapaDeltaFoxtrot@pdf.azof.fr/chunks', {
	method: 'POST',
	body: JSON.stringify({
		url: inputData.url,
		extra_context: inputData.extraContext
	})
}).then(res => {
	res.json().then(data => {
		const buffer = 640
		const modelLimit = parseInt(inputData.tokenLimit || '4096')
		let results = data.chunks.map(c => `${c}`).join('\n')
		const attempt = buffer + preamble.split(/\s/).length + results.split(/\s/).length
		console.log('before', attempt)
		const overrun = modelLimit - attempt
		console.log('overrun', overrun)
		if (overrun < 0) {
			const trim = Math.ceil(-overrun / data.chunks.length) // trims a bit off each chunk until we fit
			console.log('trim', trim)
			results = data.chunks.map(c => c.split(/\s/).slice(0, trim).join(' ')).join('\n')
		}
		const content = `${preamble}\n${results}---\n\nReply (as JSON):`
		console.log('after', content.split(/\s/).length)
		const messages = [{ content: content, role: 'system' }]
		const input = {
			model: inputData.model || 'gpt-3.5',
			temperature: parseFloat(inputData.temperature || '0.7'),
			presence_penalty: parseFloat(inputData.presencePenalty || '-1'),
			frequency_penalty: parseFloat(inputData.frequencyPenalty || '1'),
			n: 1,
			messages: messages,
		}
		const body = JSON.stringify(input)
		callback(null, { body: body })
	}).catch(err => {
		callback(err, null)
	})   
}).catch(err => {
	 callback(err, null)
})