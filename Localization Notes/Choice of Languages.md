
Last Updated: 23.08.2024

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
    x af (Afrikaans)
    - ar (Arabic)
    - ca (Catalan) [7.5m in catalonia but more than 10m native speakers]
    - cs (Czech)
    x da (Danish)
    - nl (Dutch)
    x fi (Finnish)
    - fr (French)
    - el (Greek)
    - he (Hebrew)
    - hu (Hungarian) [9.6m hungarians, but 13m native speakers]
    - it (Italian)
    - ja (Japanese)
    x nb (Norwegian Bokmål)
    - pl (Polish)
    - pt-BR (Portuguese Brazil)
    - pt-PT (Portuguese Portugal)
    - ro (Romanian)
    - ru (Russian)
    x sr-Latn (Serbian Latin)
    - es (Spanish)
    - sv (Swedish)
    - tr (Turkish)
    - uk (Ukrainian)

**I've added the following languages, additionally to the crowdin.com languages, after consultation with ChatGPT and Claude**
    
    - th (Thai)           || ChatGPT: Predominantly in Thailand, where Thai is the official language. Most Thai people prefer using software in Thai, especially those less fluent in English.
    - id (Indonesian)     || ChatGPT: The national language of Indonesia. While English is understood by many, Indonesian is the preferred language for most Indonesians in software.
    - hi (Hindi)          || ChatGPT: A major language in India, but with strong competition from English. Many educated Indians are comfortable with English, but offering Hindi can attract users who prefer or are more comfortable with their native language.
    x ne (Nepali)         || ChatGPT: Primarily spoken in Nepal. English is not as widespread in Nepal, so Nepali support could be very beneficial.
    x bn (Bengali/Bangla) || ChatGPT: Spoken in Bangladesh and parts of India (West Bengal). English is widely used in India, but in Bangladesh, Bengali is the primary language for most users.
    x fa (Persian/Farsi)  || ChatGPT: Predominantly in Iran, Afghanistan, and Tajikistan. Persian speakers generally prefer their native language for software, with less reliance on English.
    x am (Amharic)        || ChatGPT: Spoken mainly in Ethiopia. Amharic is widely used, and English penetration is lower, making Amharic support valuable.
    x my (Burmese)        || ChatGPT: Primarily spoken in Myanmar. English is not widespread, so Burmese support is likely necessary.
    x km (Khmer)          || ChatGPT: Spoken in Cambodia. English is not as prevalent, so Khmer support would be important for local users.
    x sw (Swahili)        || ChatGPT: Swahili is one of the most widely spoken languages in Africa and is increasingly used in digital contexts, especially in East Africa.
    x ha (Hausa)          || ChatGPT: Hausa is one of the most widely spoken languages in West Africa and is used in media and communication. It is increasingly important for digital content in Northern Nigeria and surrounding regions.
    
**Update: I found that macOS itself doesn't support　the following languages:**
    (which makes it pretty pointless to support them.)
    (I've' marked these with 'x' in the lists above, and removed them from the Xcode project.)
    
    x af (Afrikaans)
    x sr-Latn (Serbian Latin) [cyrillic serbian is also not supported]
  
    x ne (Nepali)       
    x bn (Bengali/Bangla)
    x fa (Persian/Farsi) 
    x am (Amharic)       
    x my (Burmese)       
    x km (Khmer)       
    x sw (Swahili)       
    x ha (Hausa)       

**After all the considerations above, there are a few more languages that Xcode recommends (and which macOS supports) which we didn't add to MMF**
    
    x Croatian (hr)         || Me: Under 5m population -> Won't add unless someone asks
    x Malay (ms)            || Me: Internet says Malaysians are super duper good at English -> Won't add unless someone asks
    x Slovak (sk)           || Me: Slightly over 5m population -> Won't ask unless someone asks.
    x Slovenian (sl)        || Me: Under 5m population -> Won't add unless someone asks

**Update: Scandinavian languages**
    
    After everything above, the only languages *under* 10m native speakers are:
    
    x da (Danish)
    x fi (Finnish)
    x nb (Norwegian Bokmål)
    
    Since Scandinavia is also famous for excellent English proficiency, we'll remove these languages, unless someone asks.
    So the only Scandinavian language we add to MMF for now is Swedish.
    Small update: Denmark and Norway have some of the highest Mac-user-percentages. (Src: https://www.pingdom.com/blog/the-10-most-mac-friendly-countries-on-the-planet/) 
        But in my sales statistics I don't see them represented that much. So we'll still remove unless someone asks

**Summary**

Last updated: 23.08.2024

Looking back, our decision-making whether to add a language seems to follow the principle:
 
    We include a language if and only if:
        - It has ~10m+ native speakers
        - macOS is translated into that language
        - We haven't included another version of that language already 
            (E.g. Australian English vs British English) 
            (We make exceptions to this, e.g. for Chinese or Portugese)
    
    Other factors we lightly considered were:
        - The sales statistics on Gumroad. 
        - Countries of Generous Contributors in the Acknowledgements
        - Proficiency of locals in already-included language (E.g. Scandinavians speak good English.)
    
    If someone asks to translate the app into a certain language, of course we'll add that language.
