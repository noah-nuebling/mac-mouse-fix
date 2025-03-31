Mac Mouse Fix **2.2.1** มาพร้อมกับ**การรองรับ macOS Ventura** อย่างเต็มรูปแบบและการเปลี่ยนแปลงอื่นๆ

### รองรับ Ventura!
Mac Mouse Fix รองรับและทำงานได้อย่างเป็นธรรมชาติกับ macOS 13 Ventura
ขอขอบคุณเป็นพิเศษสำหรับ [@chamburr](https://github.com/chamburr) ที่ช่วยเหลือเรื่องการรองรับ Ventura ใน GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297)

การเปลี่ยนแปลงประกอบด้วย:

- อัปเดตส่วนติดต่อผู้ใช้สำหรับการอนุญาตการเข้าถึงการช่วยการเข้าถึงให้สอดคล้องกับการตั้งค่าระบบใหม่ของ Ventura
- Mac Mouse Fix จะแสดงผลอย่างถูกต้องภายใต้เมนู **System Settings > Login Items** ใหม่ของ Ventura
- Mac Mouse Fix จะตอบสนองอย่างเหมาะสมเมื่อถูกปิดการใช้งานภายใต้ **System Settings > Login Items**

### ยกเลิกการรองรับ macOS รุ่นเก่า

น่าเสียดายที่ Apple อนุญาตให้พัฒนาแอพ_สำหรับ_ macOS 10.13 **High Sierra และรุ่นใหม่กว่า**เท่านั้น เมื่อพัฒนา_จาก_ macOS 13 Ventura

ดังนั้น**เวอร์ชันต่ำสุดที่รองรับ**จึงเพิ่มขึ้นจาก 10.11 El Capitan เป็น 10.13 High Sierra

### แก้ไขข้อบกพร่อง

- แก้ไขปัญหาที่ Mac Mouse Fix เปลี่ยนพฤติกรรมการเลื่อนของ**แท็บเล็ตสำหรับวาดภาพ**บางรุ่น ดู GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)
- แก้ไขปัญหาที่**ทางลัดแป้นพิมพ์**ที่มีปุ่ม 'A' ไม่สามารถบันทึกได้ แก้ไข GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275)
- แก้ไขปัญหาที่**การกำหนดปุ่มใหม่**บางอย่างไม่ทำงานอย่างถูกต้องเมื่อใช้รูปแบบแป้นพิมพ์ที่ไม่เป็นมาตรฐาน
- แก้ไขการหยุดทำงานใน'**การตั้งค่าเฉพาะแอพ**'เมื่อพยายามเพิ่มแอพที่ไม่มี 'Bundle ID' อาจช่วยแก้ไข GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289)
- แก้ไขการหยุดทำงานเมื่อพยายามเพิ่มแอพที่ไม่มีชื่อไปยัง'**การตั้งค่าเฉพาะแอพ**' แก้ไข GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241) ขอขอบคุณเป็นพิเศษสำหรับ [jeongtae](https://github.com/jeongtae) ที่ช่วยค้นหาปัญหา!
- แก้ไขข้อบกพร่องเล็กๆ น้อยๆ และปรับปรุงการทำงานภายในเพิ่มเติม