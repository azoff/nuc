Compose a comprehensive Reply to the Query using the search results (chunks) given. The Query will contain unique keys to be referenced by the Reply, and values that describe a question to generate Answers for. The final Reply output must be formatted in valid JSON syntax, all the way through its tree. The Query and Reply must conform to the following TypeScript definitions:

```typescript
interface Answer {
		text: string,
		chunk: number
}

interface Reply {
	[question_key: string]: Answer[]
}

interface Query {
	[question_key: string]: string
}
```

All Answer text should be as short as possible, and cite the chunk that they derive their answers from in the Answer chunk field. Each chunk number is found at the beginning of each search result chunk. If multiple search results yield multiple Answers, then the resulting Answer list will have more than one Answer. Only include information found in the results and don't add any additional information. Make sure the answer is correct and don't output false content. Ignore outlier search results that have nothing to do with the question. Only answer what is asked and answer step-by-step.

Query: 
```typescript
{
    business_name: "what is the name of the business?",
    one_liner: "what does the business pitch in one sentence?",
    sectors: "which of the following sectors does the business operate in (choose one or more, comma separated)? Administrative Services, Advertising, Agriculture and Farming, Apps, Artificial Intelligence, Biotechnology, Clothing and Apparel, Commerce and Shopping, Community and Lifestyle, Consumer Electronics, Consumer Goods, Content and Publishing, Data and Analytics, Design, Education, Energy, Events, Financial Services, Food and Beverage, Gaming, Government and Military, Hardware, Health Care, Information Technology, Internet Services, Lending and Investments, Manufacturing, Media and Entertainment, Messaging and Telecommunications, Mobile, Music and Audio, Natural Resources, Navigation and Mapping, Other, Payments, Platforms, Privacy and Security, Professional Services, Real Estate, Sales and Marketing, Science and Engineering, Software, Sports, Sustainability, Transportation, Travel and Tourism, Video",
    website: "the website for the business, if one exists. domain for a founder or CEO email address could be used.",
    contact_first_name: "the first name of the CEO or founder",
    contact_last_name: "the last name of the CEO or founder",
    contact_email: "the email address of the founder",
  }
```

Search Results: