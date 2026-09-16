# Nails Talk Store Release Content

Last prepared: 2026-09-16, Asia/Ho_Chi_Minh.

Use this file as the copy/paste source for App Store Connect, TestFlight review notes, and Google Play Console. Do not commit real reviewer passwords, Apple keys, Google keys, or signing credentials into the repo.

## App identity

- App display name: `Nails Talk`
- iOS bundle id: `com.kantek.nailtalk`
- Current Flutter version: `1.0.0+1`
- Live API: `http://54.205.74.122/api`
- Live Socket: `http://54.205.74.122`

## App Store listing draft

App name:

```text
Nails Talk
```

Subtitle:

```text
Cộng đồng nail Việt Mỹ
```

Promotional text:

```text
Tìm việc salon, chia sẻ phòng ở, mua bán đồ nghề, xem phim giải trí và chat cộng đồng trong một app dành cho người Việt làm đẹp tại Mỹ.
```

Description:

```text
Nails Talk là không gian cộng đồng dành cho người Việt trong ngành làm đẹp tại Mỹ.

Bạn có thể đăng nhập một lần để theo dõi tin việc làm salon, tìm hoặc đăng phòng ở, mua bán đồ nghề, xem phim giải trí và trò chuyện trực tiếp với cộng đồng.

Tính năng chính:

• Bảng tin cộng đồng: cập nhật nhanh các khu vực việc làm, phòng ở, chợ và giải trí.
• Việc làm salon: xem tin tuyển thợ, vị trí lễ tân, quản lý và các cơ hội mới.
• Phòng ở & nhà ở: tìm phòng trống, người ở ghép hoặc đăng nhu cầu tìm phòng.
• Chợ mua bán: đăng và xem các món đồ nghề salon, nội thất, thiết bị và vật dụng cần thiết.
• Phim & giải trí: khám phá danh sách phim phù hợp cho giờ nghỉ sau ngày làm việc.
• Chat cộng đồng: tham gia nhóm chat công khai, chat riêng và cập nhật thông tin theo thời gian thực.

Nails Talk được thiết kế cho trải nghiệm tiếng Việt dễ dùng, tập trung vào nhu cầu thực tế của cộng đồng nail: làm việc, sinh hoạt, kết nối và giải trí trong cùng một nơi.
```

Keywords:

```text
nail,tiệm nail,salon,người Việt,việc làm,phòng ở,chợ,phim,chat,cộng đồng
```

What’s New:

```text
Ra mắt bản Nails Talk đầu tiên với đăng ký tài khoản, bảng tin cộng đồng, phim, chợ mua bán, việc làm, phòng ở và chat thời gian thực.
```

Primary category:

```text
Social Networking
```

Secondary category:

```text
Lifestyle
```

Support URL:

```text
TODO: Add the public support/contact URL before App Store submission.
```

Privacy Policy URL:

```text
TODO: Add the public privacy policy URL before App Store submission.
```

## TestFlight beta information

Beta app description:

```text
Nails Talk là bản thử nghiệm cho cộng đồng người Việt trong ngành nail tại Mỹ. Bản này tập trung kiểm tra đăng ký/đăng nhập, xem phim, chợ mua bán, việc làm, phòng ở và chat cộng đồng thời gian thực.
```

Beta review notes:

```text
The app requires a test account or a new registration. Testers can create a new member account from the Register tab, then open Chat, join a public group such as Movie Night Club, and send a message. The app uses the live API and Socket.IO server at http://54.205.74.122.

Reviewer test account:
Username: TODO_ADD_REVIEW_USERNAME_IN_APP_STORE_CONNECT_ONLY
Password: TODO_ADD_REVIEW_PASSWORD_IN_APP_STORE_CONNECT_ONLY

Main flows to review:
1. Register or sign in.
2. Open the feed tabs: Movies, Marketplace, Chat, and More.
3. Join a public chat room and send a text message.
4. Browse movie cards and marketplace listings.
```

## Google Play listing draft

Short description:

```text
Cộng đồng nail Việt tại Mỹ: việc làm, phòng ở, chợ, phim và chat.
```

Full description:

```text
Nails Talk giúp cộng đồng người Việt trong ngành làm đẹp tại Mỹ kết nối nhanh hơn mỗi ngày.

Trong một app, bạn có thể đăng ký tài khoản, xem tin việc làm salon, tìm phòng ở hoặc người ở ghép, mua bán đồ nghề, khám phá nội dung phim giải trí và chat với cộng đồng theo thời gian thực.

Tính năng nổi bật:

• Việc làm salon và tin tuyển thợ.
• Tin phòng ở, nhà ở và nhu cầu tìm phòng.
• Chợ mua bán thiết bị, đồ nghề và vật dụng salon.
• Phim giải trí và nội dung cộng đồng.
• Nhóm chat công khai và chat riêng realtime.
• Giao diện tiếng Việt, dễ dùng cho cộng đồng nail.

Nails Talk tập trung vào các nhu cầu thiết thực: làm việc, sinh hoạt, trao đổi thông tin và giải trí sau giờ làm.
```

## Screenshot caption ideas

1. `Bảng tin cộng đồng cho người Việt làm đẹp tại Mỹ`
2. `Tìm việc salon, thợ nail và cơ hội mới`
3. `Tìm phòng ở, nhà ở và người ở ghép`
4. `Mua bán đồ nghề, thiết bị và vật dụng salon`
5. `Tham gia nhóm chat cộng đồng thời gian thực`
6. `Khám phá phim và nội dung giải trí trong app`

## Privacy answers draft

Use the final production privacy policy as the source of truth. Current functional draft:

- Account data: username, optional email, optional phone, profile name, avatar.
- User content: chat messages, marketplace posts, job posts, room/property posts, saved/bookmarked items.
- Device data: device identifier may be used for login/session, chat presence, and movie access control.
- Diagnostics: server logs may contain request metadata needed for security and debugging.
- Tracking: no advertising tracking was implemented in the current app code.
- Third-party login: not implemented in the current app code.
- Payments: online payment is not implemented in the current app code.

## Pre-submission checklist

- Confirm live API health: `http://54.205.74.122/api/mobile-chat/apps`.
- Confirm Socket.IO handshake: `http://54.205.74.122/socket.io/?EIO=4&transport=polling`.
- Confirm new member registration works.
- Confirm new member can see public chat rooms, join one, and send a message.
- Confirm movie poster/banner URLs use the live host, not `127.0.0.1`.
- Add final Support URL and Privacy Policy URL in App Store Connect.
- Add reviewer credentials only inside App Store Connect / Play Console, not in this repository.
- For Android production, replace `com.example.erp_chat_flutter` and debug signing before upload.
