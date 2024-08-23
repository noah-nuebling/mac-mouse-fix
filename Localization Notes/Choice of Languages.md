
Last Updated: 22.08.2024

In the following, we describe how we arrived at the list of languages that we added for the Mac Mouse Fix project:

**The following languages are the default ones that crowdin.com recommends when creating a new project:**
    
    Considerations:
        - Crowdin uses 'Serbian Cyrillic' instead of our 'Serbian Latin'. 'Latin' being more common according to Serbian speakers on Reddit.
        - Norwegian Bokmål is the most popular written form of Norwegian and quite different from the other written form 'Nynorsk'. (So it doesn't make sense to translate the UI into 'general norwegian' with language code 'no'. Instead we choose bokmal with language code 'nb')
        - We generally don't do multiple versions of the same language (like British English and American English), unless there are specific reasons:
            1. Portugese and Brazilian portuges have stark differences afaik
            2. Our Chinese translator already made zh-Hans, zh-Hant, and zh-HK translations. Translating into those three versions of Chinese also seems to be standard practise. (Not sure why.) 

    - en (English)
    - Base (Base)

    - de (German)
    - zh-Hant (Chinese Traditional)
    - zh-HK (Chinese Hong Kong)
    - zh-Hans (Chinese Simplified)
    - ko (Korean)
    - vi (Vietnamese)
    - x af (Afrikaans)
    - ar (Arabic)
    - ca (Catalan)
    - cs (Czech)
    - da (Danish)
    - nl (Dutch)
    - fi (Finnish)
    - fr (French)
    - el (Greek)
    - he (Hebrew)
    - hu (Hungarian)
    - it (Italian)
    - ja (Japanese)
    - nb (Norwegian Bokmål)
    - pl (Polish)
    - pt-BR (Portuguese Brazil)
    - pt-PT (Portuguese Portugal)
    - ro (Romanian)
    - ru (Russian)
    - x sr-Latn (Serbian Latin)
    - es (Spanish)
    - sv (Swedish)
    - tr (Turkish)
    - uk (Ukrainian)

**I've added the following languages, additionally to the crowdin.com languages after consultation with ChatGPT and Claude**
    
    - th (Thai)             || ChatGPT: Predominantly in Thailand, where Thai is the official language. Most Thai people prefer using software in Thai, especially those less fluent in English.
    - id (Indonesian)       || ChatGPT: The national language of Indonesia. Indonesia is the 4th largest country in the world. While English is understood by many, Indonesian is the preferred language for most Indonesians in software.
    - hi (Hindi)            || ChatGPT: A major language in India, but with strong competition from English. Many educated Indians are comfortable with English, but offering Hindi can attract users who prefer or are more comfortable with their native language.
    - x ne (Nepali)         || ChatGPT: Primarily spoken in Nepal. English is not as widespread in Nepal, so Nepali support could be very beneficial.
    - x bn (Bengali/Bangla) || ChatGPT: Spoken in Bangladesh and parts of India (West Bengal). English is widely used in India, but in Bangladesh, Bengali is the primary language for most users.
    - x fa (Persian/Farsi)  || ChatGPT: Predominantly in Iran, Afghanistan, and Tajikistan. Persian speakers generally prefer their native language for software, with less reliance on English.
    - x am (Amharic)        || ChatGPT: Spoken mainly in Ethiopia. Amharic is widely used, and English penetration is lower, making Amharic support valuable.
    - x my (Burmese)        || ChatGPT: Primarily spoken in Myanmar. English is not widespread, so Burmese support is likely necessary.
    - x km (Khmer)          || ChatGPT: Spoken in Cambodia. English is not as prevalent, so Khmer support would be important for local users.
    - x sw (Swahili)        || ChatGPT: Swahili is one of the most widely spoken languages in Africa and is increasingly used in digital contexts, especially in East Africa.
    - x ha (Hausa)          || ChatGPT: Hausa is one of the most widely spoken languages in West Africa and is used in media and communication. It is increasingly important for digital content in Northern Nigeria and surrounding regions.
    
**Update: I found that macOS itself doesn't support　the following languages:**
    (which makes it pretty pointless to support them.)
    (I've' marked these with 'x' int the lists above)
    
    - af (Afrikaans)
    - sr-Latn (Serbian Latin) [cyrillic serbian is also not supported]
  
    - ne (Nepali)       
    - bn (Bengali/Bangla)
    - fa (Persian/Farsi) 
    - am (Amharic)       
    - my (Burmese)       
    - km (Khmer)       
    - sw (Swahili)       
    - ha (Hausa)       
