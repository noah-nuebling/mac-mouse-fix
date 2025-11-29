Mac Mouse Fix **3.0.6** הופך את תכונת 'אחורה' ו'קדימה' לתואמת ליישומים נוספים.
הגירסה גם מטפלת במספר באגים ובעיות.

### תכונת 'אחורה' ו'קדימה' משופרת

מיפוי כפתורי העכבר 'אחורה' ו'קדימה' **עובד כעת ביישומים נוספים**, כולל:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed ועורכי קוד אחרים
- יישומי Apple מובנים רבים כגון Preview, Notes, System Settings, App Store ו-Music
- Adobe Acrobat
- Zotero
- ועוד!

המימוש בהשראת תכונת 'Universal Back and Forward' המעולה ב-[LinearMouse](https://github.com/linearmouse/linearmouse). היא אמורה לתמוך בכל היישומים שב-LinearMouse תומך. \
בנוסף היא תומכת במספר יישומים שבדרך כלל דורשים קיצורי מקלדת כדי לנווט אחורה וקדימה, כגון System Settings, App Store, Apple Notes ו-Adobe Acrobat. Mac Mouse Fix יזהה כעת את היישומים האלה וידמה את קיצורי המקלדת המתאימים.

כל יישום שאי פעם [התבקש ב-GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) אמור להיות נתמך כעת! (תודה על המשוב!) \
אם תמצאו יישומים שעדיין לא עובדים, ספרו לי ב-[בקשת תכונה](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### טיפול בבאג 'הגלילה מפסיקה לעבוד לסירוגין'

משתמשים מסוימים חוו [בעיה](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) שבה **גלילה חלקה מפסיקה לעבוד** באופן אקראי.

למרות שמעולם לא הצלחתי לשחזר את הבעיה, יישמתי תיקון אפשרי:

היישום ינסה כעת מספר פעמים, כאשר הגדרת הסנכרון עם המסך נכשלת. \
אם זה עדיין לא עובד לאחר הניסיונות החוזרים, היישום:

- יפעיל מחדש את תהליך הרקע 'Mac Mouse Fix Helper', מה שעשוי לפתור את הבעיה
- ייצור דוח קריסה, שעשוי לעזור לאבחן את הבאג

אני מקווה שהבעיה נפתרה כעת! אם לא, ספרו לי ב-[דיווח באג](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) או דרך [אימייל](http://redirect.macmousefix.com/?target=mailto-noah).



### התנהגות משופרת של גלגל גלילה בסיבוב חופשי

Mac Mouse Fix **לא יאיץ עוד את הגלילה** עבורכם, כאשר אתם נותנים לגלגל הגלילה להסתובב בחופשיות בעכבר MX Master. (או בכל עכבר אחר עם גלגל גלילה בסיבוב חופשי.)

בעוד שתכונת 'האצת גלילה' זו שימושית בגלגלי גלילה רגילים, בגלגל גלילה בסיבוב חופשי היא עלולה להקשות על השליטה.

**שימו לב:** Mac Mouse Fix כרגע אינו תואם באופן מלא לרוב עכברי Logitech, כולל ה-MX Master. אני מתכנן להוסיף תמיכה מלאה, אבל זה כנראה ייקח זמן. בינתיים, מנהל ההתקן הצד-שלישי הטוב ביותר עם תמיכה ב-Logitech שאני מכיר הוא [SteerMouse](https://plentycom.jp/en/steermouse/).





### תיקוני באגים

- תוקנה בעיה שבה Mac Mouse Fix לפעמים היה מפעיל מחדש קיצורי מקלדת שהושבתו בעבר ב-System Settings
- תוקנה קריסה בעת לחיצה על 'Activate License'
- תוקנה קריסה בעת לחיצה על 'Cancel' מיד לאחר לחיצה על 'Activate License' (תודה על הדיווח, Ali!)
- תוקנו קריסות בעת ניסיון להשתמש ב-Mac Mouse Fix כאשר אין מסך מחובר ל-Mac שלכם
- תוקנה דליפת זיכרון ומספר בעיות נוספות מאחורי הקלעים בעת מעבר בין לשוניות ביישום

### שיפורים ויזואליים

- תוקנה בעיה שבה לשונית About הייתה לפעמים גבוהה מדי, שהוצגה ב-[3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- הטקסט בהתראה 'Free days are over' כבר לא נחתך בסינית
- תוקן באג ויזואלי בצל של שדה ה-'+' לאחר הקלטת קלט
- תוקן באג נדיר שבו טקסט ה-placeholder במסך 'Enter Your License Key' היה מופיע לא במרכז
- תוקנה בעיה שבה סמלים מסוימים המוצגים ביישום היו בצבע שגוי לאחר מעבר בין מצב כהה/בהיר

### שיפורים נוספים

- הפכתי מספר אנימציות, כגון אנימציית מעבר בין לשוניות, ליעילות מעט יותר
- הושבתה השלמת טקסט ב-Touch Bar במסך 'Enter Your License Key'
- שיפורים קטנים נוספים מאחורי הקלעים

*נערך בסיוע מצוין של Claude.*

---

בדקו גם את הגירסה הקודמת [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5).