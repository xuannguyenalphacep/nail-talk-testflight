import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/storage_service.dart';

enum AppLanguage {
  vi('vi', 'Tiếng Việt', 'VI'),
  en('en', 'English', 'EN');

  const AppLanguage(this.code, this.label, this.shortLabel);

  final String code;
  final String label;
  final String shortLabel;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    return values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.vi,
    );
  }
}

class AppLocaleController extends ChangeNotifier {
  AppLocaleController(this._storageService) {
    AppLocalizer.setCurrentLanguage(_language);
    _load();
  }

  final StorageService _storageService;

  AppLanguage _language = AppLanguage.vi;
  bool _ready = false;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  bool get ready => _ready;

  Future<void> _load() async {
    final savedCode = await _storageService.loadLanguageCode();
    _language = AppLanguage.fromCode(savedCode);
    AppLocalizer.setCurrentLanguage(_language);
    _ready = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    AppLocalizer.setCurrentLanguage(language);
    await _storageService.saveLanguageCode(language.code);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setLanguage(
      _language == AppLanguage.vi ? AppLanguage.en : AppLanguage.vi,
    );
  }
}

class AppLocalizer {
  AppLocalizer(this.language);

  final AppLanguage language;

  static AppLanguage _currentLanguage = AppLanguage.vi;

  static void setCurrentLanguage(AppLanguage language) {
    _currentLanguage = language;
  }

  static AppLocalizer get current => AppLocalizer(_currentLanguage);

  static final Map<String, String> _vi = <String, String>{
    'Launching {appName}...': 'Đang khởi chạy {appName}...',
    'Welcome to Nails Talk': 'Chào mừng đến với Nails Talk',
    'Choose the local Nails Talk space before you sign in. Your selection stays saved until you sign out.':
        'Hãy chọn không gian Nails Talk phù hợp trước khi đăng nhập. Lựa chọn này sẽ được lưu cho đến khi bạn đăng xuất.',
    'Real-time chat': 'Chat thời gian thực',
    'Secure sign-in': 'Đăng nhập an toàn',
    'Mobile ready': 'Tối ưu cho di động',
    'Pick your local Nails Talk space, then jump into jobs, movies, marketplace posts, housing leads, and live community chat.':
        'Chọn không gian Nails Talk của bạn rồi vào ngay việc làm, phim, bài đăng mua bán, tin nhà ở và chat cộng đồng trực tiếp.',
    'Real-time sync': 'Đồng bộ thời gian thực',
    'Protected access': 'Truy cập được bảo vệ',
    'Phone-first design': 'Thiết kế ưu tiên điện thoại',
    'Shared API and chat services keep conversations fast while the rest of Nails Talk keeps everything in one place.':
        'API dùng chung và dịch vụ chat giúp hội thoại luôn nhanh, còn Nails Talk giữ mọi thứ trong cùng một nơi.',
    'Available spaces': 'Không gian khả dụng',
    'Choose the Nails Talk space you want to use on this device.':
        'Chọn không gian Nails Talk bạn muốn dùng trên thiết bị này.',
    'Local preview': 'Bản xem trước cục bộ',
    'Open Nails Talk': 'Mở Nails Talk',
    'No apps available yet': 'Chưa có ứng dụng nào khả dụng',
    'Add an app record in `em_chat_apps` from the admin API to publish it here.':
        'Hãy thêm bản ghi ứng dụng trong `em_chat_apps` từ admin API để hiển thị tại đây.',
    'Unable to display the image.': 'Không thể hiển thị hình ảnh.',
    'Chat': 'Trò chuyện',
    'You have a new message.': 'Bạn có một tin nhắn mới.',
    'Open': 'Mở',
    'Tap a member to open a private chat.':
        'Chạm vào thành viên để mở đoạn chat riêng.',
    'Unable to load members right now.':
        'Hiện chưa thể tải danh sách thành viên.',
    'This group does not have visible members yet.':
        'Nhóm này chưa có thành viên hiển thị.',
    'Message': 'Tin nhắn',
    'Pinned messages': 'Tin nhắn đã ghim',
    'No data available': 'Chưa có dữ liệu',
    'Unknown': 'Không rõ',
    'Reply': 'Trả lời',
    'Unpin': 'Bỏ ghim',
    'Pin': 'Ghim',
    'Remove like': 'Bỏ thích',
    'Like': 'Thích',
    'Recall': 'Thu hồi',
    'Confirm': 'Xác nhận',
    'Do you want to recall this message?':
        'Bạn có muốn thu hồi tin nhắn này không?',
    'Cancel': 'Hủy',
    'Rooms': 'Phòng chat',
    'Community chat': 'Chat cộng đồng',
    'Back': 'Quay lại',
    'Hidden chats': 'Đoạn chat ẩn',
    'Sign out': 'Đăng xuất',
    'Search rooms': 'Tìm phòng chat',
    'Groups': 'Nhóm',
    'Direct chats': 'Chat riêng',
    'Favorites': 'Yêu thích',
    'No group chats yet': 'Chưa có nhóm chat nào',
    'No direct chats yet': 'Chưa có chat riêng nào',
    'No favorite rooms yet': 'Chưa có phòng yêu thích nào',
    'No hidden chats yet': 'Chưa có chat ẩn nào',
    'Browse admin-created public groups and tap one to join.':
        'Xem các nhóm công khai do admin tạo và chạm để tham gia.',
    'Join admin-created groups, switch into private chats, and keep local conversations in one place.':
        'Tham gia các nhóm do admin tạo, chuyển sang chat riêng và giữ mọi cuộc trò chuyện địa phương trong cùng một nơi.',
    'Existing one-to-one chats will appear here.':
        'Các cuộc trò chuyện 1-1 hiện có sẽ hiển thị ở đây.',
    'Rooms you favorite will appear here.':
        'Các phòng bạn đánh dấu yêu thích sẽ hiển thị ở đây.',
    'Rooms you hide will appear here.':
        'Các phòng bạn đã ẩn sẽ hiển thị ở đây.',
    'Tap to join this public group.': 'Chạm để tham gia nhóm công khai này.',
    'No messages yet': 'Chưa có tin nhắn nào',
    'Public group': 'Nhóm công khai',
    'Private group': 'Nhóm riêng tư',
    'Join': 'Tham gia',
    'Online': 'Đang online',
    'Private chat': 'Chat riêng',
    'Group chat': 'Chat nhóm',
    'Members': 'Thành viên',
    'Add to favorites': 'Thêm vào yêu thích',
    'Remove favorite': 'Bỏ khỏi yêu thích',
    'Restore': 'Khôi phục',
    'Hide': 'Ẩn',
    'Load older messages': 'Tải tin nhắn cũ hơn',
    'Cancel reply': 'Hủy trả lời',
    'Everyone': 'Tất cả mọi người',
    'Type a message': 'Nhập tin nhắn',
    'Image preview': 'Xem trước hình ảnh',
    'File preview': 'Xem trước tệp',
    'Unable to open the file.': 'Không thể mở tệp.',
    '[Image]': '[Hình ảnh]',
    '[File]': '[Tệp]',
    '[Message]': '[Tin nhắn]',
    'Feed': 'Bảng tin',
    'Movies': 'Phim',
    'Market': 'Chợ',
    'Work': 'Việc',
    'Chat tab': 'Chat',
    'Work & Stay': 'Việc làm & Nhà ở',
    'Room Share': 'Chia sẻ phòng',
    'US': 'Mỹ',
    'One place for salon work, room share, and local updates.':
        'Một nơi cho công việc salon, chia sẻ phòng ở và cập nhật cộng đồng địa phương.',
    'Nails Talk is built for Vietnamese beauty professionals in the U.S. Sign in once, then move between job leads, housing posts, movie access, marketplace finds, and live chat without extra setup.':
        'Nails Talk được xây cho cộng đồng làm đẹp người Việt tại Mỹ. Chỉ cần đăng nhập một lần là bạn có thể chuyển qua lại giữa việc làm, nhà ở, phim, chợ cộng đồng và chat trực tiếp mà không cần thiết lập thêm.',
    'Salon-ready profiles': 'Hồ sơ sẵn sàng cho salon',
    'Room share and housing': 'Chia sẻ phòng và nhà ở',
    'Real-time community chat': 'Chat cộng đồng thời gian thực',
    'Always available': 'Luôn sẵn sàng',
    'Fast local auth and chat sync for everyday use.':
        'Đăng nhập cục bộ nhanh và đồng bộ chat mượt để dùng hằng ngày.',
    'Core spaces': 'Khu vực chính',
    'Feed, movies, market, work & stay, and chat.':
        'Bảng tin, phim, chợ, việc làm & nhà ở, và chat.',
    'Community-first': 'Ưu tiên cộng đồng',
    'Made for Vietnamese beauty workers across America.':
        'Thiết kế dành cho người Việt làm ngành làm đẹp trên khắp nước Mỹ.',
    'Sign in': 'Đăng nhập',
    'Sign-in failed.': 'Đăng nhập thất bại.',
    'Sign-up failed.': 'Đăng ký thất bại.',
    'Create your account': 'Tạo tài khoản',
    'Use your username and password to enter the {appName} community.':
        'Dùng tên đăng nhập và mật khẩu để vào cộng đồng {appName}.',
    'Set up your {appName} profile once and start posting jobs, rooms, marketplace items, and chat updates.':
        'Thiết lập hồ sơ {appName} một lần rồi bắt đầu đăng việc làm, phòng ở, món hàng và cập nhật chat.',
    'Register': 'Đăng ký',
    'Need an account? Create one here':
        'Chưa có tài khoản? Tạo tài khoản tại đây',
    'Already have an account? Sign in': 'Đã có tài khoản? Đăng nhập',
    'By continuing you agree to local community rules and respectful communication.':
        'Tiếp tục nghĩa là bạn đồng ý với quy định cộng đồng địa phương và cách giao tiếp tôn trọng.',
    'Username': 'Tên đăng nhập',
    'Enter your username': 'Nhập tên đăng nhập',
    'Enter a username': 'Hãy nhập tên đăng nhập',
    'Password': 'Mật khẩu',
    'Enter your password': 'Nhập mật khẩu',
    'Your account opens feed, movies, room share, marketplace, and chat in one sign-in.':
        'Chỉ với một lần đăng nhập, tài khoản của bạn sẽ mở bảng tin, phim, chia sẻ phòng, chợ và chat.',
    'Signing in...': 'Đang đăng nhập...',
    'Enter Nails Talk': 'Vào Nails Talk',
    'Full name': 'Họ và tên',
    'Enter your full name': 'Nhập họ và tên',
    'Choose a username': 'Chọn tên đăng nhập',
    'Email': 'Email',
    'Enter your email': 'Nhập email',
    'Enter a valid email address': 'Nhập địa chỉ email hợp lệ',
    'Phone number': 'Số điện thoại',
    'Recovery email': 'Email khôi phục',
    'Optional': 'Không bắt buộc',
    'Use at least 6 characters': 'Dùng ít nhất 6 ký tự',
    'Confirm password': 'Xác nhận mật khẩu',
    'Repeat your password': 'Nhập lại mật khẩu',
    'Confirm your password': 'Xác nhận mật khẩu của bạn',
    'Passwords do not match': 'Mật khẩu không khớp',
    'You can update jobs, room posts, marketplace items, and your profile after account creation.':
        'Sau khi tạo tài khoản, bạn có thể cập nhật tin việc làm, bài đăng phòng ở, món hàng chợ và hồ sơ của mình.',
    'Quick sign-up: use a unique username and password now. Email can be added now or later in your profile.':
        'Đăng ký nhanh: chỉ cần tên đăng nhập không trùng và mật khẩu. Email có thể nhập ngay hoặc bổ sung sau trong hồ sơ.',
    'Creating account...': 'Đang tạo tài khoản...',
    'Create account': 'Tạo tài khoản',
    'Your Nails Talk community is ready. Sign in to chat, watch, play, and connect in one place.':
        'Cộng đồng Nails Talk đã sẵn sàng. Đăng nhập để trò chuyện, xem phim, giải trí và kết nối trong cùng một nơi.',
    'Nails Talk is preparing your space. Tap retry and we will bring everything in shortly.':
        'Nails Talk đang chuẩn bị không gian của bạn. Chạm thử lại, mọi thứ sẽ sẵn sàng ngay sau đó.',
    'Retry': 'Thử lại',
    'Unable to connect to {appName} right now.':
        'Hiện không thể kết nối tới {appName}.',
    'Service setup is still loading. Please try again.':
        'Dịch vụ vẫn đang khởi tạo. Vui lòng thử lại.',
    'Registration details are invalid or already in use.':
        'Thông tin đăng ký không hợp lệ hoặc đã được sử dụng.',
    'Incorrect username or password.':
        'Tên đăng nhập hoặc mật khẩu không đúng.',
    'Service configuration was not found.': 'Không tìm thấy cấu hình dịch vụ.',
    'Sign-up failed. Please try again later.':
        'Đăng ký thất bại. Vui lòng thử lại sau.',
    'Sign-in failed. Please try again later.':
        'Đăng nhập thất bại. Vui lòng thử lại sau.',
    'State': 'Bang',
    'Select a state': 'Chọn bang',
    'Loading US states...': 'Đang tải danh sách bang tại Mỹ...',
    'All states': 'Tất cả bang',
    'Post Job': 'Đăng tin tuyển dụng',
    'Post Looking for Job': 'Đăng hồ sơ tìm việc',
    'Create a hiring post for nail technicians, salon staff, managers, or part-time team members.':
        'Tạo bài tuyển dụng cho kỹ thuật viên nail, nhân viên salon, quản lý hoặc cộng tác viên bán thời gian.',
    'Create a profile for professionals looking for work, a new salon, or licensing support.':
        'Tạo hồ sơ cho người đang tìm việc, tìm salon mới hoặc cần hỗ trợ về giấy phép.',
    'Hiring nail staff': 'Đăng Kiếm Thợ',
    'Job seekers': 'Kiếm Việc Làm',
    'Job Title': 'Chức danh công việc',
    'Profile Headline': 'Tiêu đề hồ sơ',
    'Salon Name': 'Tên salon',
    'Current Salon / Experience': 'Salon hiện tại / Kinh nghiệm',
    'Job Description': 'Mô tả công việc',
    'About Me': 'Giới thiệu bản thân',
    'Requirements': 'Yêu cầu',
    'Skills / Preferences': 'Kỹ năng / Mong muốn',
    'Salary Min': 'Lương tối thiểu',
    'Salary Max': 'Lương tối đa',
    'City': 'Thành phố',
    'Listing photos': 'Ảnh bài đăng',
    'Add photos': 'Thêm ảnh',
    'Uploading images...': 'Đang tải ảnh lên...',
    'Choose photos from your device and the app will upload them automatically.':
        'Chọn ảnh từ máy, ứng dụng sẽ tự tải lên tự động.',
    'Tap add photos to choose images from your device.':
        'Nhấn thêm ảnh để chọn ảnh từ thiết bị của bạn.',
    'Add salon or profile photos from your device so people can trust the post faster.':
        'Thêm ảnh salon hoặc ảnh hồ sơ từ thiết bị để người xem tin tưởng bài đăng nhanh hơn.',
    'Choose clear product photos from your device and the app will upload them automatically.':
        'Chọn ảnh sản phẩm rõ nét từ thiết bị, ứng dụng sẽ tự tải lên.',
    'Upload room or home photos from your device so renters can review the space quickly.':
        'Tải ảnh phòng hoặc nhà từ thiết bị để người thuê xem không gian nhanh hơn.',
    'Could not upload the selected image.':
        'Hiện chưa thể tải ảnh đã chọn lên.',
    'Entertainment preview': 'Góc giải trí',
    'An entertainment room for friends and the local nail community is coming soon to Nails Talk.':
        'Phòng giải trí dành cho bạn bè và cộng đồng Nails Talk sẽ sớm ra mắt.',
    'Four-player tables': 'Bàn 4 người',
    'Play with friends': 'Chơi cùng bạn bè',
    'Preview feature': 'Xem trước',
    'Image URLs (comma or new line separated)':
        'URL hình ảnh (ngăn cách bằng dấu phẩy hoặc xuống dòng)',
    'Phone': 'Điện thoại',
    'Posting...': 'Đang đăng...',
    'Publish Job': 'Đăng tin tuyển dụng',
    'Publish Profile': 'Đăng hồ sơ',
    'Required': 'Bắt buộc',
    'Create Market Listing': 'Tạo bài đăng mua bán',
    'Title': 'Tiêu đề',
    'Category': 'Danh mục',
    'No category': 'Không chọn danh mục',
    'Description': 'Mô tả',
    'Price (USD)': 'Giá (USD)',
    'Publish Listing': 'Đăng bài',
    'Listing Title': 'Tiêu đề bài đăng',
    'Post Rental': 'Đăng cho thuê',
    'Post Room Request': 'Đăng tìm phòng',
    'Post Room Share': 'Đăng chia sẻ phòng',
    'Post a room share, rental home, or housing request anywhere in the United States.':
        'Đăng tin chia sẻ phòng, nhà cho thuê hoặc nhu cầu tìm chỗ ở ở bất kỳ đâu tại Hoa Kỳ.',
    'Post a rental home or housing request anywhere in the United States.':
        'Đăng tin cho mướn nhà hoặc nhu cầu cần chỗ ở ở bất kỳ đâu tại Hoa Kỳ.',
    'Room share': 'Chia sẻ phòng',
    'Homes for rent': 'Cho mướn nhà',
    'Looking for a room': 'Cần mướn nhà',
    'Need Title': 'Tiêu đề nhu cầu',
    'What you are looking for': 'Bạn đang tìm gì',
    'Price': 'Giá',
    'Deposit': 'Tiền cọc',
    'Preferred Area / Address': 'Khu vực / địa chỉ mong muốn',
    'Address': 'Địa chỉ',
    'Amenities (comma separated)': 'Tiện ích (ngăn cách bằng dấu phẩy)',
    'Post Hiring Request': 'Đăng tin kiếm thợ',
    'Post Job Search': 'Đăng tin kiếm việc làm',
    'Post Housing Need': 'Đăng tin cần mướn nhà',
    'Post Rental Home': 'Đăng tin cho mướn nhà',
    'Publish Worker Search': 'Đăng tin kiếm thợ',
    'Publish Job Search': 'Đăng tin kiếm việc làm',
    'Publish Housing Need': 'Đăng tin cần mướn nhà',
    'Publish Rental Home': 'Đăng tin cho mướn nhà',
    'Create a hiring post so salon owners can quickly find nail staff, front-desk help, or support workers.':
        'Tạo bài đăng để chủ salon nhanh chóng tìm thợ nail, lễ tân hoặc người hỗ trợ phù hợp.',
    'Create a job-search profile so salons can discover your skills and contact you faster.':
        'Tạo hồ sơ tìm việc để salon dễ thấy kỹ năng của bạn và liên hệ nhanh hơn.',
    'Change language': 'Đổi ngôn ngữ',
    'Language': 'Ngôn ngữ',
    'Vietnamese': 'Tiếng Việt',
    'English': 'Tiếng Anh',
    'Refresh': 'Làm mới',
    'Logout': 'Đăng xuất',
    'Account': 'Tài khoản',
    'Account menu': 'Menu tài khoản',
    'Manage your profile, app help, and community policies.':
        'Quản lý hồ sơ, phần trợ giúp ứng dụng và chính sách cộng đồng.',
    'Edit profile': 'Chỉnh sửa hồ sơ',
    'FAQ': 'Câu hỏi thường gặp',
    'Q&A': 'Hỏi đáp',
    'Terms & Conditions': 'Điều khoản & điều kiện',
    'Privacy Policy': 'Chính sách riêng tư',
    'Need quick help? Start here before posting, chatting, or buying.':
        'Cần hỗ trợ nhanh? Xem tại đây trước khi đăng bài, chat hoặc mua bán.',
    'Answers for common posting, account, and chat situations.':
        'Các câu trả lời cho những tình huống thường gặp khi đăng bài, dùng tài khoản và chat.',
    'Please use respectful language, truthful listings, and only post services, housing, movies, and items that fit the community.':
        'Hãy dùng ngôn ngữ tôn trọng, đăng tin trung thực và chỉ chia sẻ dịch vụ, nhà ở, phim và món hàng phù hợp với cộng đồng.',
    'Your account details are used to sign in, display your profile, and keep chat and listing activity tied to your account.':
        'Thông tin tài khoản được dùng để đăng nhập, hiển thị hồ sơ và gắn hoạt động chat, bài đăng với đúng tài khoản của bạn.',
    'Profile updated.': 'Đã cập nhật hồ sơ.',
    'Could not update profile right now.': 'Hiện chưa thể cập nhật hồ sơ.',
    'Please review your profile details and try again.':
        'Vui lòng kiểm tra lại thông tin hồ sơ và thử lại.',
    'Display name': 'Tên hiển thị',
    'Avatar photo': 'Ảnh đại diện',
    'Choose avatar photo from your device instead of pasting a link.':
        'Chọn ảnh đại diện trực tiếp từ thiết bị thay vì dán liên kết.',
    'Choose from device': 'Chọn từ máy',
    'Change avatar': 'Đổi ảnh đại diện',
    'Remove avatar': 'Xóa ảnh đại diện',
    'Avatar image URL': 'URL ảnh đại diện',
    'Short bio': 'Giới thiệu ngắn',
    'Tell members what kind of nail work, services, or local interests you want to share.':
        'Cho mọi người biết bạn làm mảng nail nào, dịch vụ gì hoặc mối quan tâm địa phương bạn muốn chia sẻ.',
    'Saving...': 'Đang lưu...',
    'Save changes': 'Lưu thay đổi',
    'Account details': 'Thông tin tài khoản',
    'Not added yet': 'Chưa thêm',
    'Add a recovery email so you can reset your password later.':
        'Hãy thêm email khôi phục để sau này bạn có thể đặt lại mật khẩu.',
    'Change password': 'Đổi mật khẩu',
    'Use your current password once, then set a new one for future sign-ins.':
        'Nhập mật khẩu hiện tại một lần rồi đặt mật khẩu mới cho những lần đăng nhập sau.',
    'Current password': 'Mật khẩu hiện tại',
    'Enter your current password': 'Nhập mật khẩu hiện tại',
    'New password': 'Mật khẩu mới',
    'Enter your new password': 'Nhập mật khẩu mới',
    'Confirm new password': 'Xác nhận mật khẩu mới',
    'Updating password...': 'Đang cập nhật mật khẩu...',
    'Update password': 'Cập nhật mật khẩu',
    'Password changed.': 'Đã đổi mật khẩu.',
    'Could not change password right now.': 'Hiện chưa thể đổi mật khẩu.',
    'Forgot password?': 'Quên mật khẩu?',
    'Reset password': 'Đặt lại mật khẩu',
    'Enter your email or username. Nails Talk will prepare a recovery code so you can set a new password.':
        'Nhập email hoặc tên đăng nhập. Nails Talk sẽ chuẩn bị mã khôi phục để bạn đặt mật khẩu mới.',
    'Email or username': 'Email hoặc tên đăng nhập',
    'Enter your email or username': 'Nhập email hoặc tên đăng nhập',
    'Sending recovery code...': 'Đang gửi mã khôi phục...',
    'Send recovery code': 'Gửi mã khôi phục',
    'Recovery code ready for this demo.':
        'Mã khôi phục đã sẵn sàng cho bản demo này.',
    'Recovery code sent.': 'Đã gửi mã khôi phục.',
    'Demo code': 'Mã demo',
    'Recovery code': 'Mã khôi phục',
    'Enter the recovery code': 'Nhập mã khôi phục',
    'Save new password': 'Lưu mật khẩu mới',
    'Resetting password...': 'Đang đặt lại mật khẩu...',
    'Could not start password recovery.':
        'Hiện chưa thể bắt đầu khôi phục mật khẩu.',
    'Could not reset the password yet.': 'Hiện chưa thể đặt lại mật khẩu.',
    'Current password is incorrect.': 'Mật khẩu hiện tại không đúng.',
    'A recovery code is ready. Add a real email in your profile to receive recovery emails later.':
        'Mã khôi phục đã sẵn sàng. Hãy thêm email thật trong hồ sơ để lần sau có thể nhận email khôi phục.',
    'If the account exists, a recovery code has been prepared.':
        'Nếu tài khoản tồn tại, mã khôi phục đã được chuẩn bị.',
    'Invalid or expired recovery code.':
        'Mã khôi phục không đúng hoặc đã hết hạn.',
    'Password updated. Please sign in again.':
        'Mật khẩu đã được cập nhật. Vui lòng đăng nhập lại.',
    'How do I post a job quickly?': 'Đăng tin tuyển dụng nhanh như thế nào?',
    'Open the Work tab, choose hiring or job seeker mode, fill in the basics, and publish.':
        'Mở tab Việc, chọn chế độ tuyển dụng hoặc tìm việc, điền thông tin cơ bản rồi đăng.',
    'How do I contact a seller or recruiter?':
        'Liên hệ người bán hoặc nhà tuyển dụng như thế nào?',
    'Tap the contact or chat button on any listing and Nails Talk will open a direct chat room.':
        'Chạm nút liên hệ hoặc chat trên bất kỳ bài đăng nào và Nails Talk sẽ mở phòng chat riêng.',
    'Why can some movies require a plan?':
        'Vì sao một số phim yêu cầu mua gói?',
    'Some titles are free while premium shelves unlock after an active movie plan is purchased.':
        'Một số phim miễn phí, còn các kệ phim cao cấp sẽ mở sau khi tài khoản có gói phim đang hoạt động.',
    'How do I join a group chat?': 'Tham gia chat nhóm như thế nào?',
    'Admin-created groups appear in the Chat tab. Tap a group to join and start reading or sending messages.':
        'Các nhóm do admin tạo sẽ xuất hiện ở tab Chat. Chạm vào nhóm để tham gia và bắt đầu đọc hoặc gửi tin nhắn.',
    'Can I switch language later?': 'Tôi có thể đổi ngôn ngữ sau không?',
    'Yes. Use the language button in the app header to switch between Vietnamese and English.':
        'Có. Hãy dùng nút ngôn ngữ ở header ứng dụng để chuyển giữa tiếng Việt và tiếng Anh.',
    'What if my listing does not appear right away?':
        'Nếu bài đăng chưa hiện ngay thì sao?',
    'Pull to refresh first. If it is still missing, check whether the post was saved as draft or is waiting for approval.':
        'Trước tiên hãy kéo xuống để làm mới. Nếu vẫn chưa thấy, hãy kiểm tra xem bài đăng có đang là bản nháp hoặc đang chờ duyệt không.',
    'What should I put in my profile?': 'Tôi nên điền gì vào hồ sơ?',
    'Use a clear name, optional phone, short bio, and a clean avatar so salons and community members can recognize you faster.':
        'Hãy dùng tên rõ ràng, số điện thoại nếu muốn, phần giới thiệu ngắn và ảnh đại diện gọn gàng để salon và thành viên nhận ra bạn nhanh hơn.',
    'What if chat with another member does not open?':
        'Nếu chat với thành viên khác không mở thì sao?',
    'Make sure the listing has a valid owner account. If the room already exists but is hidden, Nails Talk will restore it automatically.':
        'Hãy chắc rằng bài đăng có tài khoản chủ bài hợp lệ. Nếu phòng chat đã tồn tại nhưng đang bị ẩn, Nails Talk sẽ tự khôi phục lại.',
    'Community Terms': 'Điều khoản cộng đồng',
    'Account safety': 'An toàn tài khoản',
    'Do not post scams, duplicate listings, harassment, or illegal content. Admin can remove content or disable accounts that break these rules.':
        'Không đăng lừa đảo, tin trùng lặp, quấy rối hoặc nội dung bất hợp pháp. Admin có thể xóa nội dung hoặc khóa tài khoản vi phạm các quy định này.',
    'Privacy & data': 'Quyền riêng tư & dữ liệu',
    'Shared content visibility': 'Mức độ hiển thị nội dung chia sẻ',
    'If you share a phone number, address, or media in posts or chat, other members may see that content based on where you post it.':
        'Nếu bạn chia sẻ số điện thoại, địa chỉ hoặc media trong bài đăng hay chat, các thành viên khác có thể nhìn thấy nội dung đó tùy nơi bạn đăng.',
    'Watch now': 'Xem ngay',
    'View movie': 'Xem phim',
    'Hiring feed': 'Bảng tin việc làm',
    'Fresh community openings with room to grow.':
        'Những cơ hội mới trong cộng đồng với nhiều dư địa phát triển.',
    'Open jobs': 'Mở việc làm',
    'No hiring posts yet': 'Chưa có tin tuyển dụng nào',
    'New openings will show here as soon as recruiters and salon owners publish them.':
        'Các cơ hội mới sẽ hiển thị ở đây ngay khi chủ salon và người tuyển dụng đăng tin.',
    'Live community chat is one tap away':
        'Chat cộng đồng trực tiếp chỉ cách một lần chạm',
    'Jump into group rooms or direct messages whenever you want faster answers about work, rooms, or local life.':
        'Vào ngay phòng nhóm hoặc tin nhắn riêng bất cứ lúc nào khi bạn cần câu trả lời nhanh hơn về công việc, chỗ ở hay cuộc sống địa phương.',
    'Open chat': 'Mở chat',
    'Mở chat ngay': 'Mở chat ngay',
    'Chat rooms': 'Phòng chat',
    'Marketplace picks': 'Gợi ý chợ cộng đồng',
    'Salon marketplace finds, tools, and local deals in one scroll.':
        'Dụng cụ salon, món hàng cộng đồng và ưu đãi địa phương được gom trong một màn cuộn.',
    'Useful finds, salon gear, and community listings.':
        'Những món hữu ích, đồ nghề salon và bài đăng cộng đồng.',
    'Community market': 'Chợ cộng đồng',
    'Open market': 'Mở chợ',
    'Mua và bán': 'Mua và bán',
    'Rooms and housing': 'Phòng ở và nhà ở',
    'Places to stay, shared rooms, and new move-in leads.':
        'Chỗ ở, phòng chia sẻ và các đầu mối chuyển vào ở mới.',
    'Browse homes': 'Xem nhà ở',
    'Browse housing': 'Xem nhà ở',
    'Saved for later': 'Đã lưu để xem sau',
    'Keep the most useful posts within reach.':
        'Giữ những bài đăng hữu ích nhất luôn trong tầm tay.',
    'Discover': 'Khám phá',
    'Explore': 'Khám phá',
    'Guest': 'Khách',
    'Heart-to-heart chat': 'Trò chuyện và Tâm Sự',
    'Movie picks': 'Phim Hay',
    'Find a job': 'Kiếm Việc Làm',
    'Find a tech': 'Đăng Kiếm Thợ',
    'Buy & Sell': 'Mua Và Bán',
    'Rent out a home': 'Cho mướn nhà',
    'Need a room': 'Cần mướn nhà',
    'Latest openings': 'Tin tuyển mới',
    'Hiring salons': 'Salon đang tuyển',
    'Trò chuyện và Tâm Sự': 'Trò chuyện và Tâm Sự',
    'Xem phim hay': 'Xem phim hay',
    'Kiếm Việc Làm': 'Kiếm Việc Làm',
    'Kiếm Thợ': 'Đăng Kiếm Thợ',
    'Đăng Kiếm Thợ': 'Đăng Kiếm Thợ',
    'Mua Và Bán': 'Mua Và Bán',
    'Cho mướn nhà': 'Cho mướn nhà',
    'Cần mướn nhà': 'Cần mướn nhà',
    'Join community rooms and private chats right away.':
        'Vào phòng cộng đồng và chat riêng ngay.',
    'Featured movies for a relaxed night in.':
        'Những bộ phim nổi bật cho buổi tối thư giãn.',
    'Latest salon openings and nearby job posts.':
        'Tin tuyển dụng salon mới và cơ hội gần bạn.',
    'Salon gear, decor, and daily community deals.':
        'Đồ nghề salon, decor và món hời mỗi ngày.',
    'Find a room or roommate close to work.':
        'Tìm phòng hoặc người ở ghép gần chỗ làm.',
    'Homes and rooms ready for move-in now.':
        'Nhà và phòng trống sẵn sàng dọn vào ở.',
    'Salon owners hiring and looking for the right tech.':
        'Salon đang tuyển và tìm đúng người thợ phù hợp.',
    'Tìm việc nhanh': 'Tìm việc nhanh',
    'Tìm thợ nhanh': 'Tìm thợ nhanh',
    'Xem nhà cho thuê': 'Xem nhà cho thuê',
    'Tien len card game': 'Game bài tiến lên',
    'Game bài tiến lên': 'Game bài tiến lên',
    'Bấm vào để xem trước tính năng giải trí sắp ra mắt.':
        'Bấm vào để xem trước tính năng giải trí sắp ra mắt.',
    'Coming soon': 'Sắp ra mắt',
    'Tien len card game is coming soon.': 'Game bài tiến lên sẽ sớm ra mắt.',
    'Welcome back, {name}': 'Chào mừng quay lại, {name}',
    'Find jobs, movie nights, homes, and local updates in one place.':
        'Tìm việc làm, đêm xem phim, chỗ ở và cập nhật địa phương trong cùng một nơi.',
    'Start with what you need today. This feed is tuned for work leads, marketplace finds, movie access, and places to stay.':
        'Hãy bắt đầu từ điều bạn cần hôm nay. Bảng tin này được tối ưu cho đầu mối việc làm, món đồ chợ cộng đồng, quyền xem phim và nơi để ở.',
    'Jobs & Housing': 'Việc làm & Nhà ở',
    'Jobs': 'Việc làm',
    'Housing': 'Nhà ở',
    'Active: {plan}': 'Đang hoạt động: {plan}',
    'Active: {planName}': 'Đang hoạt động: {planName}',
    'Plan active: {plan}': 'Gói đang hoạt động: {plan}',
    'Plan active: {planName}': 'Gói đang hoạt động: {planName}',
    'Subscription ready': 'Đã sẵn sàng theo gói',
    'From {amount}': 'Từ {amount}',
    'Up to {amount}': 'Tối đa {amount}',
    'MOVIE SPOTLIGHT': 'ĐIỂM NHẤN PHIM',
    'Your next movie night starts here':
        'Đêm xem phim tiếp theo của bạn bắt đầu từ đây',
    'Use this slot for fresh releases, community promotions, or a paid streaming highlight that deserves attention.':
        'Hãy dùng vị trí này cho phim mới, nội dung cộng đồng nổi bật hoặc một điểm nhấn phát trực tuyến có thu phí đáng chú ý.',
    'Community streaming': 'Phát trực tuyến cộng đồng',
    'Browse movies': 'Xem danh sách phim',
    'Watch movie': 'Xem phim',
    'See library': 'Xem thư viện',
    'Community hiring post': 'Bài đăng tuyển dụng cộng đồng',
    'Open job board': 'Mở bảng việc làm',
    'Marketplace is still quiet': 'Khu chợ vẫn còn vắng',
    'Fresh listings will show up here as soon as the marketplace starts moving.':
        'Các tin đăng mới sẽ xuất hiện ở đây ngay khi khu chợ bắt đầu sôi động.',
    'Marketplace item': 'Món hàng chợ cộng đồng',
    'No housing posts yet': 'Chưa có bài đăng nhà ở nào',
    'New room shares and housing posts will surface here when they are published.':
        'Các tin chia sẻ phòng và nhà ở mới sẽ xuất hiện ở đây khi được đăng.',
    'From {date}': 'Từ ngày {date}',
    'Housing post': 'Bài đăng nhà ở',
    'U.S. listing': 'Tin đăng tại Mỹ',
    'No saved items yet': 'Chưa có mục nào được lưu',
    'Saved jobs, housing posts, and marketplace listings will surface here for quick access.':
        'Các việc làm, bài đăng nhà ở và tin mua bán đã lưu sẽ hiện ở đây để bạn truy cập nhanh.',
    'Saved item': 'Mục đã lưu',
    'Saved': 'Đã lưu',
    'Marketplace listing': 'Tin mua bán',
    'Job listing': 'Tin việc làm',
    'Property listing': 'Tin nhà ở',
    'Published': 'Đã đăng',
    'Draft': 'Bản nháp',
    'Pending': 'Chờ duyệt',
    'Inactive': 'Tạm ẩn',
    'Hiring': 'Tuyển dụng',
    'Looking for job': 'Tìm việc',
    'Saved items are still syncing right now. The rest of the feed is ready to use.':
        'Các mục đã lưu vẫn đang đồng bộ. Những phần còn lại của bảng tin đã sẵn sàng để dùng.',
    'One feed section is not available yet. Pull down to refresh in a moment.':
        'Một phần của bảng tin hiện chưa khả dụng. Hãy kéo xuống để làm mới sau ít phút.',
    'Your session needs attention. Please sign in again.':
        'Phiên đăng nhập của bạn cần được xử lý. Vui lòng đăng nhập lại.',
    'The feed is taking longer than usual to load. Please try again shortly.':
        'Bảng tin đang tải lâu hơn bình thường. Vui lòng thử lại sau ít phút.',
    'A few sections could not be loaded right now. Pull down to try again.':
        'Một vài mục hiện chưa tải được. Hãy kéo xuống để thử lại.',
    'friend': 'bạn',
    'Marketplace': 'Chợ cộng đồng',
    'Post Item': 'Đăng món hàng',
    'Search products': 'Tìm sản phẩm',
    'Browse by category': 'Duyệt theo danh mục',
    'All categories': 'Tất cả danh mục',
    'My posts': 'Bài đăng của tôi',
    'View details': 'Xem chi tiết',
    'Save item': 'Lưu bài',
    'About this item': 'Về món hàng này',
    'Seller info': 'Thông tin người bán',
    'Name': 'Tên',
    'This seller chat is not available yet.':
        'Hiện chưa thể mở chat với người bán này.',
    'Message seller': 'Nhắn người bán',
    'This stream link is not available yet.':
        'Liên kết phát này hiện chưa khả dụng.',
    'Unable to load the movie stream right now.':
        'Hiện chưa thể tải luồng phát phim.',
    '{plan} is now active for this account.':
        '{plan} hiện đã được kích hoạt cho tài khoản này.',
    'Could not activate the plan right now.':
        'Hiện chưa thể kích hoạt gói này.',
    'Movie feature': 'Điểm nổi bật phim',
    'Internet library': 'Thư viện Internet',
    'Free access': 'Xem miễn phí',
    'Monthly access': 'Gói theo tháng',
    'Active until {date}': 'Hiệu lực đến {date}',
    'About this movie': 'Giới thiệu phim',
    'Now playing': 'Đang phát',
    'Loading your stream...': 'Đang tải luồng phát...',
    'Preparing video controls...': 'Đang chuẩn bị điều khiển video...',
    'Loading video stream...': 'Đang tải video...',
    'Pause': 'Tạm dừng',
    'Play': 'Phát',
    'Loading fullscreen player...': 'Đang tải trình phát toàn màn hình...',
    'Buffering video...': 'Đang đệm video...',
    'Fullscreen': 'Toàn màn hình',
    'Your plan is active. Refresh this page or reopen the movie to start streaming.':
        'Gói của bạn đang hoạt động. Hãy tải lại trang này hoặc mở lại phim để bắt đầu xem.',
    'This title is part of the monthly movie access plan.':
        'Tựa phim này thuộc gói xem phim theo tháng.',
    '{currency} {price} for {days} days':
        '{currency} {price} trong {days} ngày',
    'Activate': 'Kích hoạt',
    'Popular on Nails Talk': 'Nổi bật trên Nails Talk',
    'Top picks laid out like a real streaming browse page.':
        'Những lựa chọn nổi bật được trình bày như một trang duyệt phim thật.',
    'Featured movies': 'Phim nổi bật',
    'Ready to watch': 'Sẵn sàng để xem',
    'Open now for this account.': 'Mở ngay với tài khoản này.',
    'Open these instantly with the current account.':
        'Mở xem ngay bằng tài khoản hiện tại.',
    'Subscription picks': 'Gợi ý theo gói thuê bao',
    'Unlock these with the monthly movie pass.':
        'Mở các phim này bằng gói xem phim theo tháng.',
    'Free movie arrivals': 'Phim miễn phí mới cập nhật',
    'No monthly pass needed here.': 'Không cần gói tháng để xem các phim này.',
    'Premium shelf': 'Kệ phim cao cấp',
    'Subscription-only films in the same compact poster layout.':
        'Các phim chỉ dành cho gói thuê bao, hiển thị cùng bố cục poster gọn gàng.',
    'Browse {category} in poster rows.':
        'Duyệt {category} theo hàng poster ngang.',
    'Matching results': 'Kết quả phù hợp',
    'Filtered posters shown in the same movie-app style.':
        'Các poster đã lọc được hiển thị theo đúng phong cách ứng dụng xem phim.',
    'Keep the bright app background, but browse inside a cinema-style layout.':
        'Giữ nền sáng của ứng dụng, nhưng duyệt nội dung theo bố cục kiểu rạp chiếu phim.',
    'Cinema Browse': 'Duyệt phim kiểu rạp',
    '{count} titles arranged in poster shelves.':
        '{count} tựa phim được sắp xếp theo các kệ poster.',
    '{count} titles in {category}.': '{count} tựa phim trong mục {category}.',
    '{count} titles': '{count} tựa phim',
    'All titles': 'Tất cả phim',
    'Search movies, providers, or moods':
        'Tìm phim, nhà cung cấp hoặc thể loại cảm hứng',
    'Search movies, providers, or categories':
        'Tìm phim, nhà cung cấp hoặc thể loại',
    'Browse mode': 'Chế độ duyệt',
    'Quick filters': 'Bộ lọc nhanh',
    'All': 'Tất cả',
    'Ready': 'Sẵn sàng',
    'Free': 'Miễn phí',
    'Subscription': 'Thuê bao',
    'Categories': 'Danh mục',
    'All genres': 'Tất cả thể loại',
    'Featured movie': 'Phim nổi bật',
    'Movie rows': 'Dãy phim',
    'Swipe through posters by category and open a title in one tap.':
        'Vuốt qua các poster theo từng thể loại và mở phim chỉ với một chạm.',
    'Movie': 'Phim',
    'Plan': 'Gói',
    'Community stream': 'Luồng cộng đồng',
    'Watch': 'Xem',
    'Search in Nails Talk...': 'Tìm kiếm trên Nails Talk...',
    'Search suggestions': 'Gợi ý tìm kiếm',
    'Quick matches from movies, market, jobs, and housing.':
        'Kết quả nhanh từ phim, mua bán, việc làm và nhà ở.',
    'No matching posts found yet. Try another keyword.':
        'Chưa tìm thấy bài đăng phù hợp. Hãy thử từ khóa khác.',
    'Use the cards below to jump into movies, market, jobs, housing, or chat.':
        'Dùng các thẻ bên dưới để vào nhanh phim, chợ, việc làm, nhà ở hoặc chat.',
    'More': 'Thêm',
    'Menu': 'Menu',
    'See all': 'Xem tất cả',
    'Notifications': 'Thông báo',
    'Events': 'Sự kiện',
    'Nearby': 'Gần bạn',
    'Profile': 'Hồ sơ',
    'Settings': 'Cài đặt',
    'Suggested for you': 'Gợi ý cho bạn',
    'Personal': 'Cá nhân',
    'Other utilities': 'Tiện ích khác',
    'Ads': 'Quảng cáo',
    'Help center': 'Trung tâm trợ giúp',
    'Share app': 'Chia sẻ ứng dụng',
    'Customize menu': 'Tùy chỉnh menu',
    'Love connections': 'Kết nối yêu thương',
    'Join the Nails Talk community to connect and share every day.':
        'Tham gia cộng đồng Nails Talk để kết nối và sẻ chia mỗi ngày.',
    'Events will be polished in the next release.':
        'Mục sự kiện sẽ được hoàn thiện hơn ở bản phát hành tiếp theo.',
    'Nearby recommendations will be expanded in the next release.':
        'Gợi ý gần bạn sẽ được mở rộng hơn ở bản phát hành tiếp theo.',
    'Premium access can be connected after the next demo pass.':
        'Gói Premium sẽ được kết nối sau vòng demo tiếp theo.',
    'Ads can be managed from the admin console.':
        'Phần quảng cáo có thể được quản lý từ trang admin.',
    'App sharing will be connected in the next release.':
        'Tính năng chia sẻ ứng dụng sẽ được nối ở bản phát hành tiếp theo.',
    'Menu customization can be added after the next demo pass.':
        'Tùy chỉnh menu có thể được thêm sau vòng demo tiếp theo.',
    'Find rooms, roommates': 'Tìm phòng, ở ghép',
    'Details': 'Chi tiết',
    'Movie pass active until {date}': 'Gói xem phim hoạt động đến {date}',
    'Premium shelves are unlocked for this account.':
        'Các kệ phim cao cấp đã được mở cho tài khoản này.',
    'Unlock more titles and keep the movie rows open.':
        'Mở khóa thêm nhiều tựa phim và giữ các hàng phim luôn sẵn sàng.',
    'Active': 'Đang hoạt động',
    'Unlock': 'Mở khóa',
    'Plan required': 'Cần gói xem phim',
    'No titles match this setup': 'Không có tựa phim nào khớp bộ lọc này',
    'Clear the category or access filters to reopen the full movie shelves.':
        'Hãy xóa bộ lọc thể loại hoặc quyền truy cập để mở lại toàn bộ kệ phim.',
    'Pull to refresh and sync the latest movie list from the live API.':
        'Kéo xuống để làm mới và đồng bộ danh sách phim mới nhất từ API.',
    'Reset filters': 'Đặt lại bộ lọc',
    'soon': 'sắp có',
    'Quality movie picks, refreshed daily.':
        'Kho phim chất lượng, cập nhật mỗi ngày.',
    'Movie vault': 'Kho phim',
    'Search across the movie vault and open a title right away.':
        'Tìm trong toàn bộ kho phim và mở xem ngay chỉ với một chạm.',
    'Trending now': 'Phim thịnh hành',
    'The most opened titles inside Nails Talk this week.':
        'Những tựa phim được mở xem nhiều nhất trên Nails Talk tuần này.',
    'Free tonight': 'Phim miễn phí tối nay',
    'No plan needed for these picks.':
        'Không cần gói xem cho các lựa chọn này.',
    'Fresh releases': 'Mới cập nhật',
    'New posters and fresh streams for the week.':
        'Poster mới và luồng phim mới cập nhật trong tuần.',
    'Popular categories': 'Danh mục phổ biến',
    'Movie categories': 'Danh mục',
    'Every shelf available for browsing in one place.':
        'Tất cả danh mục phim được gom ở một nơi để bạn duyệt nhanh.',
    'Titles': 'Phim',
    'View all categories': 'Xem tất cả danh mục',
    'Newest': 'Mới nhất',
    'Top rated': 'Đánh giá cao',
    'Most watched': 'Nhiều người xem',
    'New': 'Mới',
    'Subtitled': 'Phụ đề',
    'reviews': 'đánh giá',
    'My list': 'Danh sách',
    'Watched': 'Đã xem',
    'Download': 'Tải xuống',
    'Share': 'Chia sẻ',
    'Your movie list will sync in the next demo update.':
        'Danh sách xem sau sẽ được đồng bộ ở bản demo kế tiếp.',
    'Offline movie download will be connected in the next release.':
        'Tải phim offline sẽ được kết nối ở bản phát hành tiếp theo.',
    'Tap Watch now to open the stream player right inside this detail page.':
        'Bấm Xem ngay để mở trình phát ngay trong trang chi tiết này.',
    'Cast': 'Diễn viên',
    'Movie link copied.': 'Đã sao chép liên kết phim.',
    'Post Housing': 'Đăng nhà ở',
    'Nail Jobs': 'Việc làm nail',
    'Salon owners are posting open positions here so members can quickly find the right team.':
        'Chủ salon đang đăng các vị trí cần người tại đây để cộng đồng nhanh chóng tìm đúng nơi phù hợp.',
    'Members looking for salon work appear here so owners can discover local talent quickly.':
        'Những thành viên đang tìm việc salon sẽ hiện ở đây để chủ tiệm dễ tìm ra nhân sự địa phương phù hợp.',
    'Photo-first rental posts help members browse homes and rooms available right now.':
        'Các bài đăng cho mướn nhà ưu tiên ảnh giúp thành viên xem nhanh nhà và phòng còn trống.',
    'Housing-need posts gather members who are searching for rooms, rentals, or a place to move in.':
        'Các bài đăng cần chỗ ở tập hợp người đang tìm phòng, tìm nhà thuê hoặc nơi có thể dọn vào ở.',
    'Worker search board': 'Bảng tin kiếm thợ',
    'Job seeker board': 'Bảng tin kiếm việc làm',
    'Rental board': 'Bảng tin cho mướn nhà',
    'Housing need board': 'Bảng tin cần mướn nhà',
    'Open roles are separated into a cleaner list so owners can contact the right people faster.':
        'Các vị trí đang tuyển được tách ra rõ hơn để chủ salon liên hệ đúng người nhanh hơn.',
    'Profiles from people looking for salon work are separated here for faster matching.':
        'Các hồ sơ tìm việc salon được tách riêng tại đây để ghép nhanh hơn.',
    'Posts from members who need a room or home are grouped here for quicker replies.':
        'Các bài đăng của thành viên đang cần phòng hoặc cần nhà được gom tại đây để phản hồi nhanh hơn.',
    'Available homes and rooms are grouped here so renters can browse quickly.':
        'Các nhà và phòng còn trống được gom tại đây để người thuê xem nhanh hơn.',
    'Search worker posts': 'Tìm bài đăng kiếm thợ',
    'Search job-seeker posts': 'Tìm bài đăng kiếm việc làm',
    'Search housing needs': 'Tìm bài đăng cần mướn nhà',
    'Search rental homes': 'Tìm bài đăng cho mướn nhà',
    'Hiring salon talent, shift openings, and job seekers in one mobile-friendly board.':
        'Tuyển người cho salon, ca làm mở và người tìm việc được gom trên một bảng dễ xem bằng điện thoại.',
    'Rental leads, room shares, and move-in posts laid out with cleaner cards.':
        'Tin cho thuê, chia sẻ phòng và bài đăng chuyển vào ở được trình bày bằng thẻ gọn gàng hơn.',
    'Search jobs': 'Tìm việc làm',
    'Search room listings': 'Tìm phòng ở',
    'Openings and candidate posts are easier to scan in this card layout.':
        'Bài đăng tuyển dụng và ứng viên nay dễ quét mắt hơn với kiểu thẻ mới.',
    'Room listings and housing leads now show photo-first with details below.':
        'Tin phòng ở và đầu mối nhà ở nay ưu tiên ảnh ở trên, chi tiết nằm gọn bên dưới.',
    'Find jobs, room shares, rentals, and local housing leads in framed tiles.':
        'Tìm việc làm, phòng chia sẻ, nhà cho thuê và đầu mối chỗ ở địa phương trong bố cục khung ô.',
    'This recruiter chat is not available yet.':
        'Hiện chưa thể mở chat với nhà tuyển dụng này.',
    'This host chat is not available yet.':
        'Hiện chưa thể mở chat với chủ bài đăng này.',
    'No worker-search posts yet': 'Chưa có bài đăng kiếm thợ nào',
    'No job-seeker posts yet': 'Chưa có bài đăng kiếm việc làm nào',
    'No rental-home posts yet': 'Chưa có bài đăng cho mướn nhà nào',
    'No housing-need posts yet': 'Chưa có bài đăng cần mướn nhà nào',
    'Salon owners have not posted any worker searches yet.':
        'Các chủ salon vẫn chưa đăng bài kiếm thợ nào.',
    'No members have posted a job search in this area yet.':
        'Chưa có thành viên nào đăng bài kiếm việc làm tại khu vực này.',
    'No rental homes have been posted in this area yet.':
        'Chưa có nhà cho thuê nào được đăng tại khu vực này.',
    'No members have posted a housing need in this area yet.':
        'Chưa có thành viên nào đăng nhu cầu cần chỗ ở tại khu vực này.',
    'Message candidate': 'Nhắn ứng viên',
    'Chat recruiter': 'Chat với nhà tuyển dụng',
    'Message renter': 'Nhắn người thuê',
    'Chat host': 'Chat với chủ nhà',
    'About this role': 'Về công việc này',
    'Recruiter info': 'Thông tin người đăng',
    'No specific requirements listed yet.':
        'Chưa có yêu cầu cụ thể nào được ghi.',
    'About this place': 'Về chỗ ở này',
    'Housing details': 'Chi tiết chỗ ở',
    'Available from': 'Có thể vào ở từ',
    'No extra housing notes yet.': 'Chưa có ghi chú thêm về chỗ ở này.',
    'Failed to load chat rooms.': 'Không thể tải danh sách phòng chat.',
    'Failed to join this group.': 'Không thể tham gia nhóm này.',
    'Failed to load chat history.': 'Không thể tải lịch sử chat.',
    'Failed to load older messages.': 'Không thể tải các tin nhắn cũ hơn.',
    'Failed to send the message.': 'Không thể gửi tin nhắn.',
    'Failed to send the file.': 'Không thể gửi tệp.',
    'Failed to start the chat.': 'Không thể bắt đầu cuộc trò chuyện.',
    'Failed to create the group.': 'Không thể tạo nhóm.',
    'Failed to rename the group.': 'Không thể đổi tên nhóm.',
    'Failed to update favorites.': 'Không thể cập nhật mục yêu thích.',
    'Failed to hide the room.': 'Không thể ẩn phòng chat.',
    'Failed to restore the room.': 'Không thể khôi phục phòng chat.',
    'Failed to search users.': 'Không thể tìm kiếm người dùng.',
    'Failed to load pinned messages.': 'Không thể tải các tin nhắn đã ghim.',
    'Failed to update the pin.': 'Không thể cập nhật ghim.',
    'Failed to update the like.': 'Không thể cập nhật lượt thích.',
    'Failed to recall the message.': 'Không thể thu hồi tin nhắn.',
    'This message was recalled': 'Tin nhắn này đã được thu hồi',
    'Nail technician': 'Kỹ thuật viên nail',
    'used': 'Đã qua sử dụng',
    'new': 'Mới',
    'published': 'Đã đăng',
    'active': 'Đang hoạt động',
    'pending': 'Đang chờ',
    'reviewing': 'Đang xem xét',
    'drama': 'chính kịch',
    'action': 'hành động',
    'comedy': 'hài',
    'documentary': 'tài liệu',
    'Annual Access': 'Gói năm',
    'Best value for salons or members who watch all year.':
        'Lựa chọn tiết kiệm nhất cho salon hoặc thành viên xem phim quanh năm.',
    'Drama': 'Chính kịch',
    'Action': 'Hành động',
    'Comedy': 'Hài',
    'Documentary': 'Tài liệu',
    'Romance': 'Tình cảm',
    'Fantasy': 'Kỳ ảo',
    'Adventure': 'Phiêu lưu',
    'Sci-Fi': 'Khoa học viễn tưởng',
    'Cosmos Laundromat: First Cycle': 'Cosmos Laundromat: Vòng Quay Đầu Tiên',
    'A lush open-movie fantasy about second chances, perfect for a polished premium streaming demo.':
        'Một phim giả tưởng giàu cảm xúc về cơ hội thứ hai, rất phù hợp cho màn demo phát trực tuyến cao cấp.',
    'Caminandes: Llamigos': 'Caminandes: Llamigos',
    'A bright, funny short film that gives the movie tab one genuinely free title for instant playback.':
        'Một phim ngắn tươi sáng, vui nhộn, mang đến cho tab phim một tựa miễn phí thực sự để phát ngay.',
    'Sintel': 'Sintel',
    'A cinematic fantasy journey with a strong hero image that makes the movie detail screen feel premium.':
        'Một chuyến phiêu lưu giả tưởng điện ảnh với hình tượng nhân vật chính mạnh mẽ, giúp màn chi tiết phim trở nên cao cấp.',
    'Tears of Steel': 'Tears of Steel',
    'A polished sci-fi short that gives the featured carousel a dramatic, high-contrast streaming title.':
        'Một phim khoa học viễn tưởng ngắn được hoàn thiện đẹp mắt, tạo điểm nhấn tương phản cao cho khu phim nổi bật.',
    'Salon Supplies': 'Dụng cụ salon',
    'Salon Decor': 'Trang trí salon',
    'Cars & Commute': 'Xe cộ & đi lại',
    'LED Nail Desk Lamp Bundle': 'Bộ đèn bàn nail LED',
    'Two bright desk lamps with adjustable color temperature for nail detail work.':
        'Hai đèn bàn sáng với nhiệt độ màu có thể điều chỉnh, phù hợp cho công việc nail chi tiết.',
    'Portable Acrylic Powder Starter Set': 'Bộ khởi đầu bột acrylic di động',
    'Starter kit with jars, brushes, and organizers for mobile appointments.':
        'Bộ khởi đầu gồm hũ, cọ và hộp sắp xếp dành cho các lịch hẹn di động.',
    'Front Desk Reception Chair Pair': 'Cặp ghế lễ tân quầy tiếp khách',
    'Soft-touch waiting chairs in great condition for salon reception areas.':
        'Ghế ngồi chờ êm ái, còn rất tốt, phù hợp cho khu tiếp khách salon.',
    'Reliable Salon Commute Sedan': 'Sedan đi lại cho salon đáng tin cậy',
    'Fuel-efficient commuter car ideal for salon owners traveling between stores.':
        'Xe tiết kiệm nhiên liệu, phù hợp cho chủ salon di chuyển giữa các cửa tiệm.',
    'Pedicure Spa Cart with Storage': 'Xe đẩy pedicure spa có ngăn chứa đồ',
    'Compact rolling cart for towels, polish, and treatment supplies.':
        'Xe đẩy nhỏ gọn cho khăn, sơn và đồ dùng trị liệu.',
    'Community Launch Assistant': 'Trợ lý triển khai cộng đồng',
    'Nails Talk Dallas Hub': 'Trung tâm Nails Talk Dallas',
    'Support content moderation, outreach, and onboarding for the local community rollout.':
        'Hỗ trợ kiểm duyệt nội dung, kết nối cộng đồng và hướng dẫn người dùng mới trong đợt triển khai địa phương.',
    'Strong English, basic admin skills, weekend flexibility.':
        'Tiếng Anh tốt, kỹ năng hành chính cơ bản, linh hoạt làm cuối tuần.',
    'Hiring Nail Technician for Busy Houston Salon':
        'Tuyển kỹ thuật viên nail cho salon đông khách tại Houston',
    'Pearl Tips Houston': 'Pearl Tips Houston',
    'Steady walk-ins, strong Vietnamese client base, and flexible booth or salary setup.':
        'Lượng khách vãng lai ổn định, tệp khách Việt đông và linh hoạt giữa thuê ghế hoặc lương cố định.',
    'Acrylic, dip powder, and weekend availability.':
        'Biết làm acrylic, dip powder và có thể làm cuối tuần.',
    'Looking for Nail Tech Position in San Jose':
        'Tìm vị trí kỹ thuật viên nail tại San Jose',
    'Specialized in gel art, builder gel, and soft, client-friendly service.':
        'Chuyên về gel art, builder gel và phong cách phục vụ nhẹ nhàng, thân thiện với khách.',
    'Open to commission or booth rental.':
        'Có thể nhận theo hoa hồng hoặc thuê ghế.',
    'Weekend Receptionist Needed': 'Cần tuyển lễ tân cuối tuần',
    'Bella Nails Austin': 'Bella Nails Austin',
    'Friendly front desk role handling calls, bookings, and guest greetings.':
        'Vị trí lễ tân thân thiện, phụ trách cuộc gọi, đặt lịch và đón tiếp khách.',
    'English speaking, POS experience preferred.':
        'Giao tiếp tiếng Anh tốt, ưu tiên có kinh nghiệm dùng POS.',
    'Licensed Tech Seeking Seattle Salon':
        'Kỹ thuật viên có bằng tìm salon tại Seattle',
    'Open to relocation support and interested in high-end natural nail service.':
        'Sẵn sàng nhận hỗ trợ chuyển chỗ ở và quan tâm đến dịch vụ nail tự nhiên cao cấp.',
    'Can start within two weeks.': 'Có thể bắt đầu trong vòng hai tuần.',
    'Private Room for Nail Tech Near Garland':
        'Phòng riêng cho thợ nail gần Garland',
    'Quiet furnished room, utilities included, ideal for someone working in the Dallas area.':
        'Phòng yên tĩnh, đầy đủ nội thất, đã gồm tiện ích, phù hợp cho người làm việc tại khu vực Dallas.',
    'wifi': 'wifi',
    'laundry': 'giặt sấy',
    'parking': 'chỗ đậu xe',
    'Room Share Near Vietnam Town': 'Chia sẻ phòng gần khu Việt Town',
    'Close to restaurants, salons, and public transit with a calm roommate setup.':
        'Gần nhà hàng, salon và phương tiện công cộng, ở cùng bạn cùng phòng dễ chịu.',
    'kitchen': 'bếp',
    'Looking for Room in Orlando': 'Tìm phòng ở Orlando',
    'Female nail tech looking for a clean room close to busy salon districts.':
        'Nữ kỹ thuật viên nail đang tìm phòng sạch sẽ gần các khu salon đông khách.',
    'Studio for Rent Near Houston Bellaire':
        'Studio cho thuê gần Houston Bellaire',
    'Small private studio with parking and quick access to salon districts.':
        'Studio riêng nhỏ gọn có chỗ đậu xe và di chuyển nhanh đến các khu salon.',
    'pet friendly': 'cho phép nuôi thú cưng',
    'Shared House Slot in Seattle': 'Chỗ ở ghép trong nhà chung tại Seattle',
    'Shared house with calm roommates, near bus routes and Korean grocery stores.':
        'Nhà ở ghép với bạn cùng nhà dễ chịu, gần tuyến xe buýt và siêu thị Hàn Quốc.',
    'Need salary clarification': 'Cần làm rõ mức lương',
    'The post should clarify whether training is paid.':
        'Bài đăng cần làm rõ việc đào tạo có được trả lương hay không.',
    'Need more room photos': 'Cần thêm ảnh phòng',
    'Asking for more angles of the room and bathroom.':
        'Cần thêm ảnh từ nhiều góc của phòng và nhà tắm.',
    'Movie Night Club': 'Câu lạc bộ đêm phim',
    'Room Share Alerts': 'Thông báo chia sẻ phòng',
    'West Coast Hiring': 'Tuyển dụng Bờ Tây',
    'You have {count} unread chat updates.':
        'Bạn có {count} cập nhật chat chưa đọc.',
    '{count} members': '{count} thành viên',
    '{count} members • {type}': '{count} thành viên • {type}',
    '{currency} {price} / {days} days': '{currency} {price} / {days} ngày',
    '{currency} {price} / {days}d': '{currency} {price} / {days} ngày',
    'Tonight we are featuring Behind the Chair in the movie tab.':
        'Tối nay chúng ta sẽ giới thiệu Behind the Chair trong tab phim.',
    'Perfect. I also bookmarked the new comedy release for break-time viewing.':
        'Tuyệt quá. Mình cũng đã lưu bộ phim hài mới để xem lúc nghỉ giải lao.',
    'New Dallas and San Jose room-share posts are live now.':
        'Các bài đăng chia sẻ phòng mới ở Dallas và San Jose đã lên rồi.',
    'I am checking the Orlando room leads this afternoon.':
        'Chiều nay mình sẽ xem các đầu mối phòng ở Orlando.',
    'Please push the Houston hiring post to the top of the feed today.':
        'Hôm nay hãy đẩy bài tuyển dụng Houston lên đầu bảng tin nhé.',
    'I sent one candidate from Seattle and one from Austin to review.':
        'Mình đã gửi một ứng viên từ Seattle và một ứng viên từ Austin để duyệt.',
    'Houston hiring post and new room-share cards are now live.':
        'Bài tuyển dụng Houston và các thẻ chia sẻ phòng mới đã lên sóng.',
    'Movie Night Club pinned a new community streaming highlight.':
        'Câu lạc bộ đêm phim đã ghim một nội dung phát trực tuyến cộng đồng mới.',
    'A new Orlando housing lead matches your search.':
        'Có một đầu mối nhà ở mới tại Orlando phù hợp với tìm kiếm của bạn.',
    'U': 'N',
  };

  static final Map<String, String> _enReverse = <String, String>{
    for (final entry in _vi.entries)
      if (!_vi.entries
          .takeWhile((item) => item.key != entry.key)
          .any((item) => item.value == entry.value))
        entry.value: entry.key,
  };

  String tr(String source, [Map<String, String> params = const {}]) {
    final translated = switch (language) {
      AppLanguage.vi => _vi[source] ?? source,
      AppLanguage.en => _enReverse[source] ?? source,
    };

    if (params.isEmpty) return translated;

    var output = translated;
    params.forEach((key, value) {
      output = output.replaceAll('{$key}', value);
    });
    return output;
  }
}

extension AppLocalizationX on BuildContext {
  AppLocaleController get localeController =>
      Provider.of<AppLocaleController>(this, listen: false);

  AppLocalizer get localizer => AppLocalizer(localeController.language);

  String tr(String source, [Map<String, String> params = const {}]) {
    return localizer.tr(source, params);
  }
}
