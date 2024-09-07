# Information Density

We found the 'information density' values used in LocalizationUtility.m through a process of:

1. Prompt Claude to translate UI text from MMF to language X
    - Note: Claude always messed up when (not) to translate Apple terms such as "Mission Control", which would change the result length quite a bit. After editing the prompt for like an hour it was better but not sure it worked for all languages. (ChatGPT was even worse.)
2. Use `swift repl` with a command like ```("""<Claudes Translation>""" as NSString).length``` to measure the NSString.length of Claude's translation
    - Note: You have to `import Foundation` in `swift repl` before using `NSString`
3. Divide the English string length / translated length to get the 'information density' of the translation relative to English. Then round it *up* to 1 decimal place.
    - Notes: 
      - We round since there's inaccuracies in the data anyways. (We get different results based on which LLMs we use and which strings we translate)
      - We round *up* because overestimating the information density makes us show our toast notifications longer, which is better than showing them too shortly. (Calculating the toast-notification-show-duration is the main purpose of the informationDensity.)

## Notes

- We used Simplified Chinese. From some quick tests, traditional Chinese seems to have the same information density.

## Prompt

Please faithfully translate the following text to LANGUAGE_NAME. It's UI text for my macOS app. Please use the same words, phrases, expressions, and tone that is typical in the macOS UI, as I'd like my app to feel native to macOS. Translate terms or leave them in the original based on how they are typically handled in the modern macOS UI (e.g., "Mission Control" is left untranslated in Korean, French, and Hindi but is localized in Chinese). Please only answer with the translation and nothing else. Here is the UI text:

Spaces & Mission Control

Move your mouse:
- Up to show Mission Control
- Down to show Application Windows
- Left or Right to move between Spaces

Works like swiping with 3 fingers on an Apple Trackpad

Scroll & Navigate

Scroll freely by moving your mouse in any direction

Also Navigate between pages in Safari, delete messages in Mail and more by moving your mouse left and right

Works like swiping with 2 fingers on an Apple Trackpad

Go back one page in Safari and other apps

Open links in a new tab, paste text in the Terminal, and more.

Works like clicking the middle mouse button (also called scroll wheel button or mouse button 3) on a standard mouse.

## English Count

663

## Template

("""
…
""" as NSString).length

COUNT: …
DENSITY: 663/… = …

## German

("""
Spaces & Mission Control

Bewegen Sie Ihre Maus:
- Nach oben, um Mission Control anzuzeigen
- Nach unten, um Anwendungsfenster anzuzeigen
- Nach links oder rechts, um zwischen Spaces zu wechseln

Funktioniert wie das Streichen mit 3 Fingern auf einem Apple Trackpad

Scrollen & Navigieren

Scrollen Sie frei, indem Sie Ihre Maus in beliebige Richtungen bewegen

Navigieren Sie auch zwischen Seiten in Safari, löschen Sie Nachrichten in Mail und mehr, indem Sie Ihre Maus nach links und rechts bewegen

Funktioniert wie das Streichen mit 2 Fingern auf einem Apple Trackpad

Eine Seite in Safari und anderen Apps zurückgehen

Öffnen Sie Links in einem neuen Tab, fügen Sie Text im Terminal ein und mehr.

Funktioniert wie das Klicken der mittleren Maustaste (auch Scrollrad-Taste oder Maustaste 3 genannt) auf einer Standard-Maus.
""" as NSString).length

COUNT: 828
DENSITY: 663/828  = 0.80072 = 0.9

## Simplified Chinese

("""
桌面空间和调度中心

移动鼠标：
- 向上显示调度中心
- 向下显示应用程序窗口
- 向左或向右在桌面空间间移动

效果类似在苹果触控板上用三指轻扫

滚动和导航

通过向任意方向移动鼠标自由滚动

还可以在 Safari 中在页面间导航，在邮件中删除消息，以及通过左右移动鼠标执行更多操作

效果类似在苹果触控板上用两指轻扫

在 Safari 和其他应用中返回上一页

在新标签页中打开链接，在终端中粘贴文本等

效果类似点击标准鼠标的中键（也称为滚轮按钮或鼠标按钮 3）
""" as NSString).length

COUNT: 238
DENSITY: 663/238  = 2.78571 = 2.8

## Korean

("""
스페이스 및 Mission Control

마우스를 움직이세요:
- 위로 Mission Control 표시
- 아래로 응용 프로그램 윈도우 표시
- 왼쪽 또는 오른쪽으로 스페이스 간 이동

Apple 트랙패드에서 3손가락 스와이프와 같은 방식으로 작동합니다

스크롤 및 탐색

마우스를 어느 방향으로든 자유롭게 움직여 스크롤하세요

또한 Safari에서 페이지 간 이동, Mail에서 메시지 삭제 등을 마우스를 좌우로 움직여 수행할 수 있습니다

Apple 트랙패드에서 2손가락 스와이프와 같은 방식으로 작동합니다

Safari 및 기타 앱에서 한 페이지 뒤로 가기

새 탭에서 링크 열기, 터미널에 텍스트 붙여넣기 등을 수행합니다.

표준 마우스의 가운데 버튼(스크롤 휠 버튼 또는 마우스 버튼 3이라고도 함)을 클릭하는 것과 같은 방식으로 작동합니다.
""" as NSString).length

COUNT: 422
DENSITY: 663/422  = 1.57109 = 1.6

## Vietnamese

("""
Các không gian và Mission Control

Di chuyển chuột:
- Lên để hiển thị Mission Control
- Xuống để hiển thị Cửa sổ Ứng dụng
- Trái hoặc Phải để di chuyển giữa các Không gian

Hoạt động như vuốt bằng 3 ngón tay trên Trackpad Apple

Cuộn & Điều hướng

Cuộn tự do bằng cách di chuyển chuột theo bất kỳ hướng nào

Cũng có thể Điều hướng giữa các trang trong Safari, xóa tin nhắn trong Mail và hơn thế nữa bằng cách di chuyển chuột sang trái và phải

Hoạt động như vuốt bằng 2 ngón tay trên Trackpad Apple

Quay lại trang trước trong Safari và các ứng dụng khác

Mở liên kết trong tab mới, dán văn bản trong Terminal, và hơn thế nữa.

Hoạt động như nhấp vào nút chuột giữa (còn gọi là nút con lăn hoặc nút chuột 3) trên chuột thông thường.
""" as NSString).length

COUNT: 732
DENSITY: 663/732  = 0.90574 = 1.0

## Arabic 

("""
المساحات و Mission Control

حرك الماوس:
- للأعلى لإظهار Mission Control
- للأسفل لإظهار نوافذ التطبيقات
- لليسار أو اليمين للتنقل بين المساحات

يعمل مثل التمرير بثلاثة أصابع على لوحة التعقب من Apple

التمرير والتنقل

قم بالتمرير بحرية عن طريق تحريك الماوس في أي اتجاه

يمكنك أيضًا التنقل بين الصفحات في Safari، وحذف الرسائل في البريد وغير ذلك عن طريق تحريك الماوس لليسار واليمين

يعمل مثل التمرير بإصبعين على لوحة التعقب من Apple

العودة صفحة واحدة للخلف في Safari والتطبيقات الأخرى

افتح الروابط في علامة تبويب جديدة، والصق النص في الطرفية، والمزيد.

يعمل مثل النقر على زر الماوس الأوسط (يُسمى أيضًا زر عجلة التمرير أو زر الماوس 3) على الماوس القياسي.
""" as NSString).length

COUNT: 645
DENSITY: 663/645  = 1.027907 = 1.1

## Catalan

("""
Espais i Mission Control

Mou el ratolí:
- Amunt per mostrar Mission Control
- Avall per mostrar les finestres d'aplicació
- Esquerra o dreta per moure't entre Espais

Funciona com lliscar amb 3 dits en un Trackpad d'Apple

Desplaçament i navegació

Desplaça't lliurement movent el ratolí en qualsevol direcció

També navega entre pàgines a Safari, elimina missatges a Mail i més movent el ratolí a esquerra i dreta

Funciona com lliscar amb 2 dits en un Trackpad d'Apple

Torna enrere una pàgina a Safari i altres aplicacions

Obre enllaços en una nova pestanya, enganxa text al Terminal i més.

Funciona com fer clic amb el botó central del ratolí (també anomenat botó de la roda de desplaçament o botó 3 del ratolí) en un ratolí estàndard.
""" as NSString).length

COUNT: 742
DENSITY: 663/742  = 0.89353 = 0.9

## Czech

("""
Prostory a Mission Control

Pohybujte myší:
- Nahoru pro zobrazení Mission Control
- Dolů pro zobrazení oken aplikací
- Vlevo nebo vpravo pro přesun mezi prostory

Funguje jako přejetí třemi prsty na Apple Trackpadu

Posouvání a navigace

Volně posouvejte obsah pohybem myši v libovolném směru

Také procházejte mezi stránkami v Safari, mažte zprávy v Mail a další pohybem myši doleva a doprava

Funguje jako přejetí dvěma prsty na Apple Trackpadu

Přejít zpět o jednu stránku v Safari a dalších aplikacích

Otevírejte odkazy v nové záložce, vkládejte text v Terminálu a další.

Funguje jako kliknutí prostředním tlačítkem myši (také nazýváno tlačítko rolovacího kolečka nebo třetí tlačítko myši) na standardní myši.
""" as NSString).length

COUNT: 716
DENSITY: 663/716  = 0.92598 = 1.0

## Dutch

("""
Spaces & Mission Control

Beweeg je muis:
- Omhoog om Mission Control te tonen
- Omlaag om Programmavensters te tonen
- Links of Rechts om tussen Spaces te schakelen

Werkt als vegen met 3 vingers op een Apple Trackpad

Scrollen & Navigeren

Scroll vrij door je muis in elke richting te bewegen

Navigeer ook tussen pagina's in Safari, verwijder berichten in Mail en meer door je muis naar links en rechts te bewegen

Werkt als vegen met 2 vingers op een Apple Trackpad

Ga één pagina terug in Safari en andere apps

Open koppelingen in een nieuw tabblad, plak tekst in Terminal en meer.

Werkt als klikken op de middelste muisknop (ook wel scrollwielknop of muisknop 3 genoemd) op een standaardmuis.
""" as NSString).length

COUNT: 700
DENSITY: 663/700  = 0.94714 = 1.0

## French

("""
Spaces et Mission Control

Déplacez votre souris :
- Vers le haut pour afficher Mission Control
- Vers le bas pour afficher les fenêtres de l'application
- Vers la gauche ou la droite pour vous déplacer entre les Spaces

Fonctionne comme un balayage à 3 doigts sur un trackpad Apple

Défilement et navigation

Défilez librement en déplaçant votre souris dans n'importe quelle direction

Naviguez également entre les pages dans Safari, supprimez des messages dans Mail et plus encore en déplaçant votre souris vers la gauche et la droite

Fonctionne comme un balayage à 2 doigts sur un trackpad Apple

Revenez à la page précédente dans Safari et d'autres applications

Ouvrez des liens dans un nouvel onglet, collez du texte dans le Terminal, et plus encore.

Fonctionne comme un clic sur le bouton central de la souris (également appelé bouton de la molette ou bouton 3 de la souris) sur une souris standard.
""" as NSString).length

COUNT: 908
DENSITY: 663/908  = 0.73018 = 0.8

## Greek

("""
Χώροι & Mission Control

Μετακινήστε το ποντίκι σας:
- Πάνω για εμφάνιση του Mission Control
- Κάτω για εμφάνιση των Παραθύρων Εφαρμογής
- Αριστερά ή Δεξιά για μετακίνηση μεταξύ των Χώρων

Λειτουργεί όπως το σύρσιμο με 3 δάχτυλα σε ένα Apple Trackpad

Κύλιση & Πλοήγηση

Κυλήστε ελεύθερα μετακινώντας το ποντίκι σας προς οποιαδήποτε κατεύθυνση

Επίσης, πλοηγηθείτε μεταξύ σελίδων στο Safari, διαγράψτε μηνύματα στο Mail και άλλα, μετακινώντας το ποντίκι σας αριστερά και δεξιά

Λειτουργεί όπως το σύρσιμο με 2 δάχτυλα σε ένα Apple Trackpad

Επιστροφή μία σελίδα πίσω στο Safari και άλλες εφαρμογές

Ανοίξτε συνδέσμους σε νέα καρτέλα, επικολλήστε κείμενο στο Terminal και άλλα.

Λειτουργεί όπως το κλικ στο μεσαίο κουμπί του ποντικιού (γνωστό και ως κουμπί τροχού κύλισης ή κουμπί ποντικιού 3) σε ένα τυπικό ποντίκι.
""" as NSString).length

COUNT: 801
DENSITY: 663/801  = 0.82772 = 0.9

## Hebrew

("""
חללים ו-Mission Control

הזז את העכבר שלך:
- למעלה כדי להציג את Mission Control
- למטה כדי להציג חלונות יישום
- שמאלה או ימינה כדי לנוע בין חללים

פועל כמו החלקה עם 3 אצבעות על משטח מגע של Apple

גלילה וניווט

גלול בחופשיות על ידי הזזת העכבר שלך בכל כיוון

בנוסף, נווט בין עמודים בספארי, מחק הודעות בדואר ועוד על ידי הזזת העכבר שמאלה וימינה

פועל כמו החלקה עם 2 אצבעות על משטח מגע של Apple

חזור עמוד אחד אחורה בספארי ויישומים אחרים

פתח קישורים בכרטיסייה חדשה, הדבק טקסט במסוף, ועוד.

פועל כמו לחיצה על לחצן העכבר האמצעי (הנקרא גם לחצן גלגל הגלילה או לחצן עכבר 3) בעכבר סטנדרטי.
""" as NSString).length

COUNT: 579
DENSITY: 663/579  = 1.14508 = 1.2

## Hungarian

("""
Terek és Mission Control

Mozgassa az egeret:
- Felfelé a Mission Control megjelenítéséhez
- Lefelé az Alkalmazásablakok megjelenítéséhez
- Balra vagy jobbra a Terek közötti váltáshoz

Úgy működik, mint a 3 ujjas csúsztatás az Apple trackpaden

Görgetés és Navigálás

Görgessen szabadon az egér bármely irányba mozgatásával

Navigáljon az oldalak között a Safariban, töröljön üzeneteket a Mailben és még sok mást az egér balra és jobbra mozgatásával

Úgy működik, mint a 2 ujjas csúsztatás az Apple trackpaden

Ugrás vissza egy oldalt a Safariban és más alkalmazásokban

Linkek megnyitása új fülön, szöveg beillesztése a Terminálba és még sok más.

Úgy működik, mint a középső egérgomb kattintása (más néven görgőgomb vagy 3-as egérgomb) egy hagyományos egéren.
""" as NSString).length

COUNT: 761
DENSITY: 663/761  = 0.87122 = 0.9

## Italian

("""
Spazi e Mission Control

Muovi il mouse:
- In alto per mostrare Mission Control
- In basso per mostrare le Finestre dell'Applicazione
- A sinistra o a destra per spostarti tra gli Spazi

Funziona come scorrere con 3 dita su un Trackpad Apple

Scorri e Naviga

Scorri liberamente muovendo il mouse in qualsiasi direzione

Naviga anche tra le pagine in Safari, elimina i messaggi in Mail e altro ancora muovendo il mouse a sinistra e a destra

Funziona come scorrere con 2 dita su un Trackpad Apple

Torna indietro di una pagina in Safari e altre app

Apri link in una nuova scheda, incolla testo nel Terminale e altro ancora.

Funziona come cliccare il pulsante centrale del mouse (chiamato anche pulsante della rotellina o pulsante 3 del mouse) su un mouse standard.
""" as NSString).length

COUNT: 766
DENSITY: 663/766  = 0.86554 = 0.9

## Japanese

("""
スペースとMission Control

マウスの動き:
- 上: Mission Controlを表示
- 下: アプリケーションウィンドウを表示
- 左右: スペース間を移動

Apple トラックパッドで3本指でスワイプするのと同様に機能します

スクロールとナビゲーション

マウスを任意の方向に動かして自由にスクロール

また、マウスを左右に動かしてSafariでページ間を移動したり、メールでメッセージを削除したりなど

Apple トラックパッドで2本指でスワイプするのと同様に機能します

Safariやその他のアプリで1ページ戻る

新しいタブでリンクを開いたり、ターミナルにテキストを貼り付けたりなど

標準マウスの中央ボタン（スクロールホイールボタンまたはマウスボタン3とも呼ばれる）をクリックするのと同様に機能します
""" as NSString).length

COUNT: 371
DENSITY: 663/371  = 1.78706 = 1.8

## Polish

("""
Przestrzenie i Mission Control

Poruszaj myszą:
- W górę, aby wyświetlić Mission Control
- W dół, aby wyświetlić Okna aplikacji
- W lewo lub prawo, aby przełączać się między Przestrzeniami

Działa jak przeciąganie 3 palcami na gładziku Apple

Przewijanie i nawigacja

Przewijaj swobodnie, poruszając myszą w dowolnym kierunku

Możesz także nawigować między stronami w Safari, usuwać wiadomości w Mail i więcej, przesuwając mysz w lewo i prawo

Działa jak przeciąganie 2 palcami na gładziku Apple

Wróć o jedną stronę w Safari i innych aplikacjach

Otwieraj linki w nowej karcie, wklejaj tekst w Terminalu i nie tylko.

Działa jak kliknięcie środkowym przyciskiem myszy (zwanym także przyciskiem kółka przewijania lub przyciskiem myszy 3) na standardowej myszy.
""" as NSString).length

COUNT: 760
DENSITY: 663/760  = 0.87237 = 0.9

## Brazilian Portuguese

("""
Spaces e Mission Control

Mova o mouse:
- Para cima para mostrar o Mission Control
- Para baixo para mostrar as Janelas do Aplicativo
- Para a esquerda ou direita para mover entre Spaces

Funciona como deslizar com 3 dedos em um Trackpad Apple

Rolar e Navegar

Role livremente movendo o mouse em qualquer direção

Também navegue entre páginas no Safari, exclua mensagens no Mail e muito mais movendo o mouse para a esquerda e direita

Funciona como deslizar com 2 dedos em um Trackpad Apple

Voltar uma página no Safari e em outros aplicativos

Abra links em uma nova aba, cole texto no Terminal e muito mais.

Funciona como clicar no botão do meio do mouse (também chamado de botão da roda de rolagem ou botão 3 do mouse) em um mouse padrão.
""" as NSString).length

COUNT: 743
DENSITY: 663/743  = 0.89233 = 0.9

## Romanian

("""
Spaces și Mission Control

Mișcați mouse-ul:
- În sus pentru a afișa Mission Control
- În jos pentru a afișa Ferestrele Aplicației
- La stânga sau la dreapta pentru a vă deplasa între Spaces

Funcționează ca glisarea cu 3 degete pe un Trackpad Apple

Derulare și Navigare

Derulați liber mișcând mouse-ul în orice direcție

De asemenea, navigați între pagini în Safari, ștergeți mesaje în Mail și multe altele mișcând mouse-ul la stânga și la dreapta

Funcționează ca glisarea cu 2 degete pe un Trackpad Apple

Reveniți la pagina anterioară în Safari și alte aplicații

Deschideți linkuri într-o filă nouă, lipiți text în Terminal și multe altele.

Funcționează ca un clic pe butonul din mijloc al mouse-ului (numit și butonul rotitei de derulare sau butonul 3 al mouse-ului) pe un mouse standard.
""" as NSString).length

COUNT: 797
DENSITY: 663/797  = 0.83187 = 0.9

## Russian

("""
Пространства и Mission Control

Перемещайте мышь:
- Вверх для показа Mission Control
- Вниз для показа окон приложения
- Влево или вправо для перемещения между пространствами

Работает как смахивание тремя пальцами на трекпаде Apple

Прокрутка и навигация

Свободно прокручивайте, перемещая мышь в любом направлении

Также перемещайтесь между страницами в Safari, удаляйте сообщения в Почте и выполняйте другие действия, перемещая мышь влево и вправо

Работает как смахивание двумя пальцами на трекпаде Apple

Вернуться на предыдущую страницу в Safari и других приложениях

Открывайте ссылки в новой вкладке, вставляйте текст в Терминале и выполняйте другие действия.

Работает как нажатие средней кнопки мыши (также называемой кнопкой колеса прокрутки или кнопкой мыши 3) на стандартной мыши.
""" as NSString).length

COUNT: 792
DENSITY: 663/792  = 0.83712 = 0.9

## Spanish

("""
Espacios y Mission Control

Mueve tu ratón:
- Hacia arriba para mostrar Mission Control
- Hacia abajo para mostrar las ventanas de la aplicación
- Hacia la izquierda o derecha para moverte entre Espacios

Funciona como deslizar con 3 dedos en un trackpad de Apple

Desplazamiento y navegación

Desplázate libremente moviendo tu ratón en cualquier dirección

También navega entre páginas en Safari, elimina mensajes en Mail y más moviendo tu ratón hacia la izquierda y derecha

Funciona como deslizar con 2 dedos en un trackpad de Apple

Retroceder una página en Safari y otras apps

Abre enlaces en una nueva pestaña, pega texto en Terminal y más.

Funciona como hacer clic con el botón central del ratón (también llamado botón de la rueda de desplazamiento o botón 3 del ratón) en un ratón estándar.
""" as NSString).length

COUNT: 800
DENSITY: 663/800  = 0.82875 = 0.9

## Swedish

("""
Spaces och Mission Control

Flytta musen:
- Uppåt för att visa Mission Control
- Nedåt för att visa Programfönster
- Vänster eller höger för att flytta mellan Spaces

Fungerar som att svepa med 3 fingrar på en Apple Trackpad

Rulla & Navigera

Rulla fritt genom att flytta musen i valfri riktning

Navigera även mellan sidor i Safari, radera meddelanden i Mail och mer genom att flytta musen åt vänster och höger

Fungerar som att svepa med 2 fingrar på en Apple Trackpad

Gå tillbaka en sida i Safari och andra appar

Öppna länkar i en ny flik, klistra in text i Terminal och mer.

Fungerar som att klicka på mittenknappen (även kallad rullhjulsknappen eller musknapp 3) på en standardmus.
""" as NSString).length

COUNT: 690
DENSITY: 663/690  = 0.96087 = 1.0

## Turkish

("""
Spaces ve Mission Control

Farenizi hareket ettirin:
- Mission Control'ü göstermek için yukarı
- Uygulama Pencerelerini göstermek için aşağı
- Spaces arasında geçiş yapmak için sola veya sağa

Apple Trackpad'de 3 parmakla kaydırma gibi çalışır

Kaydırma ve Gezinme

Farenizi herhangi bir yöne hareket ettirerek serbestçe kaydırın

Ayrıca farenizi sola ve sağa hareket ettirerek Safari'de sayfalar arasında gezinin, Mail'de mesajları silin ve daha fazlasını yapın

Apple Trackpad'de 2 parmakla kaydırma gibi çalışır

Safari ve diğer uygulamalarda bir sayfa geri gidin

Bağlantıları yeni sekmede açın, Terminal'de metin yapıştırın ve daha fazlasını yapın.

Standart bir farenin orta fare düğmesine (ayrıca kaydırma tekerleği düğmesi veya fare düğmesi 3 olarak da adlandırılır) tıklama gibi çalışır.
""" as NSString).length

COUNT: 796
DENSITY: 663/796  = 0.83291 = 0.9

## Ukrainian

("""
Spaces і Mission Control

Рухайте мишею:
- Вгору, щоб показати Mission Control
- Вниз, щоб показати вікна програм
- Ліворуч або праворуч, щоб переміщатися між Spaces

Працює так само, як жест проведення трьома пальцями на трекпаді Apple

Прокручування та навігація

Вільно прокручуйте, рухаючи мишею в будь-якому напрямку

Також переходьте між сторінками в Safari, видаляйте повідомлення в Mail та інше, рухаючи мишею ліворуч і праворуч

Працює так само, як жест проведення двома пальцями на трекпаді Apple

Повернутися на одну сторінку назад у Safari та інших програмах

Відкривайте посилання в новій вкладці, вставляйте текст у Terminal тощо.

Працює як натискання середньої кнопки миші (також відома як кнопка коліщатка прокручування або кнопка миші 3) на стандартній миші. """ as NSString).length

COUNT: 770
DENSITY: 663/770  = 0.86104 = 0.9

## Thai

("""
พื้นที่และ Mission Control

เลื่อนเมาส์ของคุณ:
- ขึ้นเพื่อแสดง Mission Control
- ลงเพื่อแสดงหน้าต่างแอพพลิเคชัน
- ซ้ายหรือขวาเพื่อเลื่อนระหว่างพื้นที่

ทำงานเหมือนการปัดด้วยนิ้ว 3 นิ้วบน Apple Trackpad

เลื่อนและนำทาง

เลื่อนได้อย่างอิสระโดยการเลื่อนเมาส์ของคุณไปในทิศทางใดก็ได้

ยังสามารถนำทางระหว่างหน้าใน Safari, ลบข้อความใน Mail และอื่นๆ โดยการเลื่อนเมาส์ไปทางซ้ายและขวา

ทำงานเหมือนการปัดด้วยนิ้ว 2 นิ้วบน Apple Trackpad

ย้อนกลับหนึ่งหน้าใน Safari และแอพอื่นๆ

เปิดลิงก์ในแท็บใหม่, วางข้อความใน Terminal และอื่นๆ

ทำงานเหมือนการคลิกปุ่มกลางของเมาส์ (หรือเรียกว่าปุ่มล้อเลื่อนหรือปุ่มเมาส์ที่ 3) บนเมาส์มาตรฐาน
""" as NSString).length

COUNT: 578
DENSITY: 663/578  = 1.14706 = 1.2

## Indonesian

("""
Spaces & Mission Control

Gerakkan mouse Anda:
- Ke atas untuk menampilkan Mission Control
- Ke bawah untuk menampilkan Jendela Aplikasi
- Ke kiri atau kanan untuk berpindah antar Spaces

Bekerja seperti menggeser dengan 3 jari pada Apple Trackpad

Gulir & Navigasi

Gulir bebas dengan menggerakkan mouse Anda ke segala arah

Juga Navigasi antar halaman di Safari, hapus pesan di Mail dan lainnya dengan menggerakkan mouse ke kiri dan kanan

Bekerja seperti menggeser dengan 2 jari pada Apple Trackpad

Kembali satu halaman di Safari dan aplikasi lainnya

Buka tautan di tab baru, tempel teks di Terminal, dan lainnya.

Bekerja seperti mengklik tombol tengah mouse (juga disebut tombol roda gulir atau tombol mouse 3) pada mouse standar.
""" as NSString).length

COUNT: 737
DENSITY: 663/737  = 0.89959 = 0.9

## Hindi

("""
स्पेसेज़ और Mission Control

अपने माउस को हिलाएँ:
- ऊपर की ओर Mission Control दिखाने के लिए
- नीचे की ओर एप्लिकेशन विंडोज़ दिखाने के लिए
- बाएँ या दाएँ स्पेसेज़ के बीच जाने के लिए

Apple ट्रैकपैड पर 3 उंगलियों से स्वाइप करने जैसा काम करता है

स्क्रॉल और नेविगेट

किसी भी दिशा में अपने माउस को हिलाकर स्वतंत्र रूप से स्क्रॉल करें

साथ ही Safari में पृष्ठों के बीच नेविगेट करें, Mail में संदेशों को हटाएँ और अधिक कार्य अपने माउस को बाएँ और दाएँ हिलाकर करें

Apple ट्रैकपैड पर 2 उंगलियों से स्वाइप करने जैसा काम करता है

Safari और अन्य ऐप्स में एक पृष्ठ पीछे जाएँ

लिंक को नए टैब में खोलें, Terminal में टेक्स्ट पेस्ट करें, और अधिक।

मानक माउस पर मध्य माउस बटन (जिसे स्क्रॉल व्हील बटन या माउस बटन 3 भी कहा जाता है) पर क्लिक करने जैसा काम करता है।
""" as NSString).length

COUNT: 740
DENSITY: 663/740  = 0.89595 = 0.9
