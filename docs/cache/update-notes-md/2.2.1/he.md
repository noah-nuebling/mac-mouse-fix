Mac Mouse Fix **2.2.1** מספק **תמיכה מלאה ב-macOS Ventura** לצד שינויים נוספים.

### תמיכה ב-Ventura!
Mac Mouse Fix כעת תומך באופן מלא ומרגיש טבעי ב-macOS 13 Ventura.
תודה מיוחדת ל-[@chamburr](https://github.com/chamburr) שעזר בתמיכה ב-Ventura בגיטהאב Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

השינויים כוללים:

- עדכון ממשק המשתמש להענקת גישת נגישות כדי לשקף את הגדרות המערכת החדשות של Ventura
- Mac Mouse Fix יוצג כראוי תחת תפריט **הגדרות מערכת > פריטי התחברות** החדש של Ventura
- Mac Mouse Fix יגיב כראוי כאשר הוא מושבת תחת **הגדרות מערכת > פריטי התחברות**

### הפסקת תמיכה בגרסאות ישנות של macOS

לצערנו, Apple מאפשרת לפתח _עבור_ macOS 10.13 **High Sierra ומעלה** רק כאשר מפתחים _מתוך_ macOS 13 Ventura.

לכן **הגרסה המינימלית הנתמכת** עלתה מ-10.11 El Capitan ל-10.13 High Sierra.

### תיקוני באגים

- תוקנה בעיה שבה Mac Mouse Fix משנה את התנהגות הגלילה של **טאבלטים לציור** מסוימים. ראו GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- תוקנה בעיה שבה לא ניתן היה להקליט **קיצורי מקלדת** הכוללים את המקש 'A'. מתקן את GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- תוקנה בעיה שבה **מיפויי כפתורים** מסוימים לא עבדו כראוי בעת שימוש בפריסת מקלדת לא סטנדרטית.
- תוקנה קריסה ב-'**הגדרות ספציפיות לאפליקציה**' בניסיון להוסיף אפליקציה ללא 'Bundle ID'. עשוי לעזור עם GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- תוקנה קריסה בניסיון להוסיף אפליקציות ללא שם ל-'**הגדרות ספציפיות לאפליקציה**'. פותר את GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). תודה מיוחדת ל-[jeongtae](https://github.com/jeongtae) שעזר מאוד בגילוי הבעיה!
- תיקוני באגים קטנים נוספים ושיפורים מתחת למכסה המנוע.