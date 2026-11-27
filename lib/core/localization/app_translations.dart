import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAppLanguagePrefKey = 'settings.language.code';

enum AppLanguage { vi, en }

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  // V4 (2026-11-08): English is now the primary language — new users start
  // in English; a previously saved preference is still respected.
  AppLanguageNotifier() : super(AppLanguage.en) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(kAppLanguagePrefKey) ?? 'en';
    state = code == 'vi' ? AppLanguage.vi : AppLanguage.en;
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kAppLanguagePrefKey,
      lang == AppLanguage.en ? 'en' : 'vi',
    );
  }
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier();
});

class AppTranslations {
  static const Map<String, Map<AppLanguage, String>> _keys = {
    // Navigation Shell
    'nav_home': {AppLanguage.vi: 'Trang chủ', AppLanguage.en: 'Home'},
    'nav_activity': {AppLanguage.vi: 'Tập luyện', AppLanguage.en: 'Record'},
    'nav_history': {AppLanguage.vi: 'Lịch sử', AppLanguage.en: 'History'},
    'nav_analytics': {AppLanguage.vi: 'Phân tích', AppLanguage.en: 'Analytics'},
    'nav_profile': {AppLanguage.vi: 'Hồ sơ', AppLanguage.en: 'Profile'},

    // Greetings & Subtitles
    'daily_telemetry': {
      AppLanguage.vi: 'Dữ liệu tập hàng ngày',
      AppLanguage.en: 'Daily telemetry',
    },
    'good_morning': {AppLanguage.vi: 'Chào buổi sáng', AppLanguage.en: 'Good morning'},
    'good_afternoon': {
      AppLanguage.vi: 'Chào buổi chiều',
      AppLanguage.en: 'Good afternoon',
    },
    'good_evening': {AppLanguage.vi: 'Chào buổi tối', AppLanguage.en: 'Good evening'},

    // Empty States & Standby Labels
    'ready': {AppLanguage.vi: 'Sẵn sàng', AppLanguage.en: 'Ready'},
    'first_session': {
      AppLanguage.vi: 'Buổi tập đầu tiên',
      AppLanguage.en: 'First session',
    },
    'dashboard_ready_title': {
      AppLanguage.vi: 'Bảng dữ liệu đã sẵn sàng',
      AppLanguage.en: 'Your dashboard is ready',
    },
    'dashboard_ready_sub': {
      AppLanguage.vi:
          'Hãy ghi lại một buổi tập để kích hoạt bản đồ lộ trình, phân tích hàng tuần và chuỗi tập luyện.',
      AppLanguage.en:
          'Record a workout to activate route telemetry, weekly insights, and your streak signal.',
    },
    'sessions': {AppLanguage.vi: 'Buổi tập', AppLanguage.en: 'Sessions'},
    'minutes': {AppLanguage.vi: 'Phút', AppLanguage.en: 'Minutes'},
    'select_your_mode': {
      AppLanguage.vi: 'Chọn chế độ tập của bạn',
      AppLanguage.en: 'Select your mode',
    },
    'ready_to_move': {
      AppLanguage.vi: 'Sẵn sàng vận động',
      AppLanguage.en: 'Ready to move',
    },
    'allow_gps': {AppLanguage.vi: 'Bật GPS', AppLanguage.en: 'Allow GPS'},
    'running': {AppLanguage.vi: 'Chạy bộ', AppLanguage.en: 'Running'},
    'route_timeline_standby': {
      AppLanguage.vi: 'Chờ dữ liệu lộ trình',
      AppLanguage.en: 'Route timeline standby',
    },
    'no_activity_recorded': {
      AppLanguage.vi: 'Chưa có hoạt động nào',
      AppLanguage.en: 'No activity recorded',
    },
    'no_activity_sub': {
      AppLanguage.vi:
          'Lộ trình hoàn thành và mốc thời gian tập luyện của bạn sẽ xuất hiện tại đây.',
      AppLanguage.en:
          'Your completed routes and workout timeline will appear here.',
    },
    'record_activity': {
      AppLanguage.vi: 'Ghi lại hoạt động',
      AppLanguage.en: 'Record activity',
    },
    'analysis_standby': {
      AppLanguage.vi: 'Chờ phân tích',
      AppLanguage.en: 'Analysis standby',
    },
    'no_telemetry_yet': {
      AppLanguage.vi: 'Chưa có dữ liệu thống kê',
      AppLanguage.en: 'No telemetry yet',
    },
    'no_telemetry_sub': {
      AppLanguage.vi:
          'Hoàn thành buổi tập đầu tiên để mở khóa phân tích tốc độ, khoảng cách, xu hướng và kỷ lục.',
      AppLanguage.en:
          'Complete your first workout to unlock pace, distance, trends, and records.',
    },
    'all': {AppLanguage.vi: 'Tất cả', AppLanguage.en: 'All'},
    'overview': {AppLanguage.vi: 'Tổng quan', AppLanguage.en: 'Overview'},
    'distance_trend': {
      AppLanguage.vi: 'Xu hướng khoảng cách',
      AppLanguage.en: 'Distance trend',
    },
    'achievement_records': {
      AppLanguage.vi: 'Kỷ lục đạt được',
      AppLanguage.en: 'Achievement records',
    },
    'activity_mix': {
      AppLanguage.vi: 'Tỷ lệ hoạt động',
      AppLanguage.en: 'Activity mix',
    },
    'avg_distance': {
      AppLanguage.vi: 'Khoảng cách TB',
      AppLanguage.en: 'Avg distance',
    },
    'best_pace': {
      AppLanguage.vi: 'Nhịp độ tốt nhất',
      AppLanguage.en: 'Best pace',
    },
    'days': {AppLanguage.vi: 'Ngày', AppLanguage.en: 'Days'},

    // Profile & Biometrics
    'biometric_data': {
      AppLanguage.vi: 'Dữ liệu sinh trắc',
      AppLanguage.en: 'Biometric data',
    },
    'weight': {AppLanguage.vi: 'Cân nặng', AppLanguage.en: 'Weight'},
    'height': {AppLanguage.vi: 'Chiều cao', AppLanguage.en: 'Height'},
    'age': {AppLanguage.vi: 'Tuổi', AppLanguage.en: 'Age'},
    'gender': {AppLanguage.vi: 'Giới tính', AppLanguage.en: 'Gender'},
    'years_old': {AppLanguage.vi: 'tuổi', AppLanguage.en: 'years'},
    'male': {AppLanguage.vi: 'Nam', AppLanguage.en: 'Male'},
    'female': {AppLanguage.vi: 'Nữ', AppLanguage.en: 'Female'},
    'system_actions': {
      AppLanguage.vi: 'Tiện ích & tài khoản',
      AppLanguage.en: 'Account & preferences',
    },
    'security': {AppLanguage.vi: 'Bảo mật', AppLanguage.en: 'Security'},
    'achievements': {AppLanguage.vi: 'Thành tựu', AppLanguage.en: 'Achievements'},
    'choose_from_gallery': {
      AppLanguage.vi: 'Chọn từ thư viện ảnh',
      AppLanguage.en: 'Choose from gallery',
    },
    'take_a_photo': {AppLanguage.vi: 'Chụp ảnh mới', AppLanguage.en: 'Take a photo'},
    'remove_current_photo': {
      AppLanguage.vi: 'Xóa ảnh hiện tại',
      AppLanguage.en: 'Remove current photo',
    },
    'member_since': {
      AppLanguage.vi: 'Thành viên từ',
      AppLanguage.en: 'Member since',
    },
    'display_name': {
      AppLanguage.vi: 'Tên hiển thị',
      AppLanguage.en: 'Display Name',
    },
    'edit_display_name': {
      AppLanguage.vi: 'Đổi tên gọi',
      AppLanguage.en: 'Edit Display Name',
    },
    'enter_display_name': {
      AppLanguage.vi: 'Nhập tên gọi của bạn',
      AppLanguage.en: 'Enter your display name',
    },
    'display_name_hint': {
      AppLanguage.vi: 'Tên vận động viên',
      AppLanguage.en: 'Athlete name',
    },
    'display_name_empty': {
      AppLanguage.vi: 'Tên không được để trống',
      AppLanguage.en: 'Display name cannot be empty',
    },
    'name_updated_success': {
      AppLanguage.vi: 'Đã cập nhật tên gọi thành công!',
      AppLanguage.en: 'Display name updated successfully!',
    },

    // Settings & Permissions
    'allowed': {AppLanguage.vi: 'Đã cho phép', AppLanguage.en: 'Allowed'},
    'limited': {AppLanguage.vi: 'Giới hạn', AppLanguage.en: 'Limited'},
    'restricted': {AppLanguage.vi: 'Bị hạn chế', AppLanguage.en: 'Restricted'},
    'blocked': {AppLanguage.vi: 'Bị chặn', AppLanguage.en: 'Blocked'},
    'denied': {AppLanguage.vi: 'Từ chối', AppLanguage.en: 'Denied'},
    'full_access': {AppLanguage.vi: 'Quyền đầy đủ', AppLanguage.en: 'Full Access'},
    'checking_access': {
      AppLanguage.vi: 'Đang kiểm tra quyền...',
      AppLanguage.en: 'Checking access...',
    },
    'camera_ready': {
      AppLanguage.vi: 'Sẵn sàng để chụp ảnh đại diện',
      AppLanguage.en: 'Ready for taking profile photos',
    },
    'camera_denied': {
      AppLanguage.vi: 'Nhấn để cấp quyền máy ảnh hoặc mở Cài đặt',
      AppLanguage.en: 'Tap to request camera access or open Settings',
    },
    'photos_ready': {
      AppLanguage.vi: 'Quyền đầy đủ sẵn sàng để chọn ảnh đại diện',
      AppLanguage.en: 'Full access is ready for choosing profile photos',
    },
    'photos_denied': {
      AppLanguage.vi: 'Nhấn để cấp quyền thư viện ảnh hoặc mở Cài đặt',
      AppLanguage.en: 'Tap to request photo access or open Settings',
    },
    'photos_limited': {
      AppLanguage.vi: 'Quyền giới hạn. Đổi sang Quyền đầy đủ trong Cài đặt',
      AppLanguage.en: 'Limited access. Switch to Full Access in Settings',
    },
    'location_ready': {
      AppLanguage.vi: 'Sẵn sàng theo dõi tập luyện ngoài trời',
      AppLanguage.en: 'Ready for outdoor workout tracking',
    },
    'location_denied': {
      AppLanguage.vi: 'Nhấn để cấp quyền GPS hoặc mở Cài đặt',
      AppLanguage.en: 'Tap to request GPS access or open Settings',
    },
    'clearing_cache': {
      AppLanguage.vi: 'Đang xóa tệp tạm...',
      AppLanguage.en: 'Clearing temporary files...',
    },
    'clear_cache_confirm': {
      AppLanguage.vi:
          'Bạn có chắc chắn muốn xóa bộ nhớ đệm và tệp tạm? Dữ liệu bài tập của bạn sẽ không bị xóa.',
      AppLanguage.en:
          'Are you sure you want to clear temporary files and image cache? Your workouts will not be deleted.',
    },
    'cancel': {AppLanguage.vi: 'Hủy', AppLanguage.en: 'Cancel'},
    'clear': {AppLanguage.vi: 'Xóa', AppLanguage.en: 'Clear'},
    'logout_confirm': {
      AppLanguage.vi: 'Bạn có chắc chắn muốn đăng xuất?',
      AppLanguage.en: 'Are you sure you want to log out?',
    },
    'logout_title': {
      AppLanguage.vi: 'Đăng xuất khỏi Aetron',
      AppLanguage.en: 'Log out of Aetron',
    },
    'logout_sub': {
      AppLanguage.vi:
          'Bạn có chắc chắn muốn đăng xuất? Tất cả dữ liệu tập luyện của bạn đã được đồng bộ an toàn.',
      AppLanguage.en:
          'Are you sure you want to log out? All your workout telemetry has been safely synced.',
    },

    // Auth & Onboarding
    'welcome_title': {
      AppLanguage.vi: 'Chào mừng đến với Aetron',
      AppLanguage.en: 'Welcome to Aetron',
    },
    'welcome_subtitle': {
      AppLanguage.vi: 'Theo dõi tập luyện thông minh & phân tích hiệu suất',
      AppLanguage.en: 'Smart workout tracking & performance telemetry',
    },
    'get_started': {AppLanguage.vi: 'Bắt đầu ngay', AppLanguage.en: 'Get started'},
    'login': {AppLanguage.vi: 'Đăng nhập', AppLanguage.en: 'Sign in'},
    'register': {AppLanguage.vi: 'Đăng ký', AppLanguage.en: 'Sign up'},
    'email': {AppLanguage.vi: 'Email', AppLanguage.en: 'Email'},
    'username': {AppLanguage.vi: 'Tên người dùng', AppLanguage.en: 'Username'},
    'password': {AppLanguage.vi: 'Mật khẩu', AppLanguage.en: 'Password'},
    'confirm_password': {
      AppLanguage.vi: 'Xác nhận mật khẩu',
      AppLanguage.en: 'Confirm password',
    },
    'password_mismatch': {
      AppLanguage.vi: 'Mật khẩu xác nhận không khớp',
      AppLanguage.en: 'Passwords do not match',
    },
    'password_cannot_contain_username': {
      AppLanguage.vi: 'Mật khẩu không được trùng hoặc chứa tên đăng nhập',
      AppLanguage.en: 'Password cannot match or contain your username',
    },
    'no_username_rule': {
      AppLanguage.vi: 'Không chứa tên user',
      AppLanguage.en: 'No username',
    },
    'mandatory_password_upgrade_title': {
      AppLanguage.vi: 'Yêu cầu nâng cấp mật khẩu',
      AppLanguage.en: 'Mandatory password upgrade',
    },
    'forgot_password': {
      AppLanguage.vi: 'Quên mật khẩu?',
      AppLanguage.en: 'Forgot password?',
    },
    'dont_have_account': {
      AppLanguage.vi: 'Chưa có tài khoản?',
      AppLanguage.en: "Don't have an account?",
    },
    'already_have_account': {
      AppLanguage.vi: 'Đã có tài khoản?',
      AppLanguage.en: 'Already have an account?',
    },
    'sign_in_google': {
      AppLanguage.vi: 'Đăng nhập bằng Google',
      AppLanguage.en: 'Sign in with Google',
    },
    'enter_email': {
      AppLanguage.vi: 'Nhập tên người dùng hoặc email',
      AppLanguage.en: 'Enter username or email',
    },
    'enter_username': {
      AppLanguage.vi: 'Nhập tên người dùng',
      AppLanguage.en: 'Enter username',
    },
    'enter_password': {
      AppLanguage.vi: 'Nhập mật khẩu',
      AppLanguage.en: 'Enter password',
    },
    'welcome_back': {
      AppLanguage.vi: 'Chào mừng trở lại',
      AppLanguage.en: 'Welcome back',
    },
    'create_account': {
      AppLanguage.vi: 'Tạo tài khoản',
      AppLanguage.en: 'Create account',
    },
    'signin_subtitle': {
      AppLanguage.vi: 'Đăng nhập để tiếp tục lộ trình tập luyện của bạn.',
      AppLanguage.en: 'Sign in to pick up where you left off.',
    },
    'register_subtitle': {
      AppLanguage.vi: 'Tham gia Aetron để bắt đầu theo dõi tập luyện ngay.',
      AppLanguage.en: 'Join Aetron to track your fitness telemetry.',
    },
    'reset_password': {
      AppLanguage.vi: 'Khôi phục mật khẩu',
      AppLanguage.en: 'Reset password',
    },

    // Home Dashboard
    'home_title': {AppLanguage.vi: 'Trang chủ', AppLanguage.en: 'Home'},
    'running_series': {AppLanguage.vi: 'Chuỗi bài tập runner', AppLanguage.en: 'Running series'},
    'aetron_streak': {AppLanguage.vi: 'Chuỗi tập Aetron', AppLanguage.en: 'Aetron streak'},
    'days_streak': {AppLanguage.vi: 'Ngày chuỗi tập', AppLanguage.en: 'Days streak'},
    'streak_active': {AppLanguage.vi: 'Chuỗi tập đang hoạt động', AppLanguage.en: 'Streak active'},
    'start_your_streak': {AppLanguage.vi: 'Bắt đầu chuỗi tập ngay', AppLanguage.en: 'Start your streak'},
    'milestone_unlocked': {AppLanguage.vi: 'Đã mở khóa cột mốc', AppLanguage.en: 'Milestone unlocked'},
    'days_left': {AppLanguage.vi: 'Ngày nữa', AppLanguage.en: 'Days left'},
    'this_week': {AppLanguage.vi: 'Tuần này', AppLanguage.en: 'This week'},
    'continue_workout': {AppLanguage.vi: 'Tiếp tục tập luyện →', AppLanguage.en: 'Continue workout →'},
    'runner_programs': {AppLanguage.vi: 'Giáo án chạy bộ', AppLanguage.en: 'Running plans'},
    'coaching_guide': {AppLanguage.vi: 'Hướng dẫn cách chạy', AppLanguage.en: 'Running & coaching guide'},
    'start_program': {AppLanguage.vi: 'Bắt đầu chạy ngay →', AppLanguage.en: 'Start program now →'},
    'how_to_execute': {AppLanguage.vi: 'Phương pháp thực hiện bài chạy', AppLanguage.en: 'How to execute this workout'},
    'beginner_runner': {AppLanguage.vi: 'Người mới bắt đầu', AppLanguage.en: 'Beginner runner'},
    'couch_to_5k': {AppLanguage.vi: 'Hành trình 5K cho người mới', AppLanguage.en: 'Couch to 5K program'},
    'pace_builder_10k': {AppLanguage.vi: 'Xây dựng tốc độ 10K', AppLanguage.en: '10K pace builder'},
    'easy_base_run': {AppLanguage.vi: 'Chạy thả lỏng & phục hồi', AppLanguage.en: 'Easy recovery base run'},
    'speed_intervals': {AppLanguage.vi: 'Luyện tốc độ 5K Interval', AppLanguage.en: '5K speed intervals'},
    'spotlight': {AppLanguage.vi: 'Nổi bật', AppLanguage.en: 'Spotlight'},
    'workout_modes': {AppLanguage.vi: 'Chế độ tập', AppLanguage.en: 'Workout modes'},
    'gym': {AppLanguage.vi: 'Gym', AppLanguage.en: 'Gym'},
    'cardio': {AppLanguage.vi: 'Cardio', AppLanguage.en: 'Cardio'},
    'yoga': {AppLanguage.vi: 'Yoga', AppLanguage.en: 'Yoga'},
    'ready_to_move_sub': {
      AppLanguage.vi: 'Cùng đạt mục tiêu hôm nay nhé',
      AppLanguage.en: "Let's achieve your goals today",
    },
    'set_goal_title': {AppLanguage.vi: 'Mục tiêu tập luyện', AppLanguage.en: 'Fitness target'},
    'select_workout': {AppLanguage.vi: 'Chọn bài tập', AppLanguage.en: 'Select workout'},
    'location_context': {AppLanguage.vi: 'Vị trí GPS hiện tại', AppLanguage.en: 'Location context'},
    'start_activity': {AppLanguage.vi: 'Bắt đầu chạy ngay →', AppLanguage.en: 'Start workout now →'},
    'what_achievement': {AppLanguage.vi: 'Bạn muốn đạt được mục tiêu nào?', AppLanguage.en: 'What do you want to achieve?'},
    'your_target': {AppLanguage.vi: 'Mục tiêu của bạn', AppLanguage.en: 'Your target'},
    'goal_period': {AppLanguage.vi: 'Thời gian mục tiêu', AppLanguage.en: 'Goal period'},
    'your_goal_summary': {AppLanguage.vi: 'Tổng quan mục tiêu', AppLanguage.en: 'Your goal summary'},
    'save_goal': {AppLanguage.vi: 'Lưu mục tiêu →', AppLanguage.en: 'Save goal →'},
    'update_goal': {AppLanguage.vi: 'Cập nhật mục tiêu →', AppLanguage.en: 'Update goal →'},
    'analytics_title': {AppLanguage.vi: 'Thống kê hiệu suất', AppLanguage.en: 'Performance analytics'},
    'units_subtitle': {AppLanguage.vi: 'Sử dụng hệ mét (KM, KG) hoặc hệ Anh (MI, LB)', AppLanguage.en: 'Use Metric (KM, KG) or Imperial (MI, LB)'},
    'biometric_stats': {AppLanguage.vi: 'Chỉ số sinh trắc', AppLanguage.en: 'Biometric stats'},
    'select_activity_mode': {AppLanguage.vi: 'Chọn chế độ tập luyện', AppLanguage.en: 'Select your activity'},
    'running_desc': {AppLanguage.vi: 'Theo dõi tốc độ, thời gian & khoảng cách chạy bộ', AppLanguage.en: 'Track speed, duration & running distance'},
    'cycling_desc': {AppLanguage.vi: 'Đo lường vận tốc & hành trình đạp xe', AppLanguage.en: 'Measure outdoor velocity & cycling routes'},
    'walking_desc': {AppLanguage.vi: 'Đếm bước chân & đi bộ hàng ngày', AppLanguage.en: 'Pedometer & daily active step tracking'},
    'gps_required': {AppLanguage.vi: 'Yêu cầu GPS', AppLanguage.en: 'GPS required'},
    'gps_optional': {AppLanguage.vi: 'GPS tùy chọn', AppLanguage.en: 'GPS optional'},
    'start_mode': {AppLanguage.vi: 'Bắt đầu chế độ →', AppLanguage.en: 'Start mode →'},
    'gps_ready_status': {AppLanguage.vi: 'GPS đã sẵn sàng', AppLanguage.en: 'GPS ready'},
    'gps_disabled_status': {AppLanguage.vi: 'Vị trí / GPS chưa được bật', AppLanguage.en: 'Location / GPS is disabled'},
    'enable_gps_action': {AppLanguage.vi: 'Bật GPS / Cấp quyền vị trí', AppLanguage.en: 'Enable GPS / Grant location'},
    'security_upgrade_title': {AppLanguage.vi: 'Nâng cấp mật khẩu bảo mật', AppLanguage.en: 'Security password upgrade'},
    'security_upgrade_desc': {AppLanguage.vi: 'Theo chính sách bảo mật mới, tài khoản cần cập nhật mật khẩu có chữ hoa, chữ thường, số & ký tự đặc biệt.', AppLanguage.en: 'According to new security policy, please update your password to include uppercase, lowercase, number & special char.'},
    'update_password_action': {AppLanguage.vi: 'Cập nhật mật khẩu ngay →', AppLanguage.en: 'Update password now →'},
    'new_password': {AppLanguage.vi: 'Mật khẩu mới', AppLanguage.en: 'New password'},
    'password_updated_success': {AppLanguage.vi: 'Mật khẩu đã được nâng cấp bảo mật thành công!', AppLanguage.en: 'Password updated with strong security successfully!'},
    'your_performance': {AppLanguage.vi: 'Phân tích kết quả tập luyện', AppLanguage.en: 'Your performance analytics'},
    'personal_bests': {AppLanguage.vi: 'Kỷ lục cá nhân', AppLanguage.en: 'Personal bests'},
    'goal_progress': {AppLanguage.vi: 'Tiến độ mục tiêu', AppLanguage.en: 'Goal progress'},
    'workout_history': {AppLanguage.vi: 'Lịch sử tập luyện', AppLanguage.en: 'Workout history'},
    'this_period': {AppLanguage.vi: 'Giai đoạn này', AppLanguage.en: 'This period'},
    'no_workouts_yet': {AppLanguage.vi: 'Chưa có buổi tập nào', AppLanguage.en: 'No workouts recorded yet'},
    'empty_history_desc': {AppLanguage.vi: 'Hoàn thành buổi tập đầu tiên để theo dõi lịch sử tại đây.', AppLanguage.en: 'Complete your first workout to track your history here.'},
    'quick_start': {AppLanguage.vi: 'Tập luyện ngay', AppLanguage.en: 'Quick start'},
    'ai_insights': {AppLanguage.vi: 'Gợi ý từ AI', AppLanguage.en: 'AI insights'},
    'recent_activities': {
      AppLanguage.vi: 'Hoạt động gần đây',
      AppLanguage.en: 'Recent activities',
    },
    'see_all': {AppLanguage.vi: 'Xem tất cả', AppLanguage.en: 'See all'},
    'distance': {AppLanguage.vi: 'Khoảng cách', AppLanguage.en: 'Distance'},
    'duration': {AppLanguage.vi: 'Thời gian', AppLanguage.en: 'Duration'},
    'calories': {AppLanguage.vi: 'Calo', AppLanguage.en: 'Calories'},
    'pace': {AppLanguage.vi: 'Nhịp độ', AppLanguage.en: 'Pace'},
    'avg_pace': {AppLanguage.vi: 'Nhịp độ trung bình', AppLanguage.en: 'Avg pace'},
    'avg_pace_short': {AppLanguage.vi: 'Nhịp độ TB', AppLanguage.en: 'Avg pace'},
    'avg_pace_upper': {AppLanguage.vi: 'Nhịp độ trung bình', AppLanguage.en: 'Avg pace'},
    'weekly_summary': {
      AppLanguage.vi: 'Tóm tắt tuần',
      AppLanguage.en: 'Weekly summary',
    },
    'streak': {
      AppLanguage.vi: 'Chuỗi tập luyện',
      AppLanguage.en: 'Workout streak',
    },

    // Workout Flow
    'start_workout': {
      AppLanguage.vi: 'Bắt đầu tập',
      AppLanguage.en: 'Start workout',
    },
    'outdoor_run': {
      AppLanguage.vi: 'Chạy bộ ngoài trời',
      AppLanguage.en: 'Outdoor run',
    },
    'indoor_run': {
      AppLanguage.vi: 'Chạy máy (Treadmill)',
      AppLanguage.en: 'Indoor run',
    },
    'cycling': {AppLanguage.vi: 'Đạp xe', AppLanguage.en: 'Cycling'},
    'walking': {AppLanguage.vi: 'Đi bộ', AppLanguage.en: 'Walking'},
    'Cycling': {AppLanguage.vi: 'Đạp xe', AppLanguage.en: 'Cycling'},
    'Walking': {AppLanguage.vi: 'Đi bộ', AppLanguage.en: 'Walking'},
    'Running': {AppLanguage.vi: 'Chạy bộ', AppLanguage.en: 'Running'},
    'gps_searching': {
      AppLanguage.vi: 'Đang tìm tín hiệu GPS...',
      AppLanguage.en: 'Searching for GPS signal...',
    },
    'gps_ready': {
      AppLanguage.vi: 'GPS đã sẵn sàng',
      AppLanguage.en: 'GPS signal ready',
    },
    'pause': {AppLanguage.vi: 'Tạm dừng', AppLanguage.en: 'Pause'},
    'resume': {AppLanguage.vi: 'Tiếp tục', AppLanguage.en: 'Resume'},
    'finish': {AppLanguage.vi: 'Hoàn thành', AppLanguage.en: 'Finish'},
    'discard': {AppLanguage.vi: 'Hủy bỏ', AppLanguage.en: 'Discard'},
    'heart_rate': {AppLanguage.vi: 'Nhịp tim', AppLanguage.en: 'Heart rate'},
    'cadence': {AppLanguage.vi: 'Nhịp bước', AppLanguage.en: 'Cadence'},
    'workout_summary': {
      AppLanguage.vi: 'Tóm tắt buổi tập',
      AppLanguage.en: 'Workout summary',
    },
    'workout_details': {
      AppLanguage.vi: 'Chi tiết buổi tập',
      AppLanguage.en: 'Workout details',
    },
    'save_workout': {
      AppLanguage.vi: 'Lưu buổi tập',
      AppLanguage.en: 'Save workout',
    },

    // History & Calendar
    'calendar': {AppLanguage.vi: 'Lịch tập luyện', AppLanguage.en: 'Workout calendar'},
    'no_activities': {
      AppLanguage.vi: 'Chưa có hoạt động nào trong ngày này',
      AppLanguage.en: 'No activities recorded for this day',
    },
    'filter': {AppLanguage.vi: 'Lọc', AppLanguage.en: 'Filter'},
    'all_activities': {
      AppLanguage.vi: 'Tất cả hoạt động',
      AppLanguage.en: 'All activities',
    },

    // Analytics & Stats
    'analytics': {
      AppLanguage.vi: 'Thống kê & phân tích',
      AppLanguage.en: 'Analytics & stats',
    },
    'week': {AppLanguage.vi: 'Tuần', AppLanguage.en: 'Week'},
    'month': {AppLanguage.vi: 'Tháng', AppLanguage.en: 'Month'},
    'year': {AppLanguage.vi: 'Năm', AppLanguage.en: 'Year'},
    'vo2_max': {AppLanguage.vi: 'Chỉ số VO2 Max', AppLanguage.en: 'VO2 Max indicator'},
    'pace_distribution': {
      AppLanguage.vi: 'Phân bố nhịp độ',
      AppLanguage.en: 'Pace distribution',
    },
    'heart_rate_zones': {
      AppLanguage.vi: 'Vùng nhịp tim',
      AppLanguage.en: 'Heart rate zones',
    },
    'total_distance': {
      AppLanguage.vi: 'Tổng khoảng cách',
      AppLanguage.en: 'Total distance',
    },
    'total_workouts': {
      AppLanguage.vi: 'Tổng số buổi tập',
      AppLanguage.en: 'Total workouts',
    },

    // Profile & Setup
    'profile': {AppLanguage.vi: 'Hồ sơ cá nhân', AppLanguage.en: 'Profile'},
    'personal_records': {
      AppLanguage.vi: 'Kỷ lục cá nhân',
      AppLanguage.en: 'Personal records',
    },
    'goals': {AppLanguage.vi: 'Mục tiêu', AppLanguage.en: 'Goals'},
    'create_goal': {
      AppLanguage.vi: 'Tạo mục tiêu mới',
      AppLanguage.en: 'Create new goal',
    },
    'edit_profile': {
      AppLanguage.vi: 'Chỉnh sửa hồ sơ',
      AppLanguage.en: 'Edit profile',
    },
    'badges': {
      AppLanguage.vi: 'Huy hiệu & thành tích',
      AppLanguage.en: 'Badges & achievements',
    },
    'athlete_level': {
      AppLanguage.vi: 'Cấp độ vận động viên',
      AppLanguage.en: 'Athlete level',
    },
    'save_changes': {
      AppLanguage.vi: 'Lưu thay đổi',
      AppLanguage.en: 'Save changes',
    },

    // Activity
    'activity': {AppLanguage.vi: 'Hoạt động', AppLanguage.en: 'Activity'},
    'share_workout': {
      AppLanguage.vi: 'Chia sẻ buổi tập',
      AppLanguage.en: 'Share workout',
    },
    'delete_workout': {
      AppLanguage.vi: 'Xóa buổi tập',
      AppLanguage.en: 'Delete workout',
    },
    'confirm_delete_workout': {
      AppLanguage.vi: 'Bạn có chắc chắn muốn xóa buổi tập này không?',
      AppLanguage.en: 'Are you sure you want to delete this workout?',
    },
    'outdoor_session': {
      AppLanguage.vi: 'Buổi tập ngoài trời',
      AppLanguage.en: 'Outdoor session',
    },
    'outdoor_mode': {
      AppLanguage.vi: 'Chế độ ngoài trời',
      AppLanguage.en: 'Outdoor mode',
    },
    'flexible_start': {
      AppLanguage.vi: 'Bắt đầu linh hoạt',
      AppLanguage.en: 'Flexible start',
    },
    'gps_off': {AppLanguage.vi: 'Tắt GPS', AppLanguage.en: 'GPS off'},
    'gps_on': {AppLanguage.vi: 'Bật GPS', AppLanguage.en: 'GPS on'},
    'gps_status': {AppLanguage.vi: 'Trạng thái GPS', AppLanguage.en: 'GPS status'},
    'route_locked': {AppLanguage.vi: 'Đã khóa lộ trình', AppLanguage.en: 'Route locked'},
    'route_pending': {AppLanguage.vi: 'Đang tìm lộ trình', AppLanguage.en: 'Route pending'},
    'gps_settings': {AppLanguage.vi: 'Cài đặt GPS', AppLanguage.en: 'GPS settings'},
    'locating': {AppLanguage.vi: 'Đang định vị', AppLanguage.en: 'Locating'},
    'live_map': {AppLanguage.vi: 'Bản đồ trực tiếp', AppLanguage.en: 'Live map'},
    'checking': {AppLanguage.vi: 'Đang kiểm tra', AppLanguage.en: 'Checking'},
    'location_blocked': {
      AppLanguage.vi: 'Bị chặn vị trí',
      AppLanguage.en: 'Location blocked',
    },
    'location_services_off': {
      AppLanguage.vi: 'Dịch vụ vị trí đang tắt',
      AppLanguage.en: 'Location services are off',
    },
    'outdoor_tracking_ready': {
      AppLanguage.vi: 'Theo dõi ngoài trời sẵn sàng',
      AppLanguage.en: 'Outdoor tracking is ready',
    },
    'location_access_blocked': {
      AppLanguage.vi: 'Quyền vị trí đã bị chặn',
      AppLanguage.en: 'Location access is blocked',
    },
    'location_permission_needed': {
      AppLanguage.vi: 'Cần cấp quyền vị trí',
      AppLanguage.en: 'Location permission is needed',
    },
    'workout_saved': {
      AppLanguage.vi: 'Đã lưu bài tập',
      AppLanguage.en: 'Workout saved',
    },
    'route_not_available': {
      AppLanguage.vi: 'Không có lộ trình',
      AppLanguage.en: 'Route not available',
    },
    'moving_pace': {
      AppLanguage.vi: 'Nhịp độ di chuyển',
      AppLanguage.en: 'Moving pace',
    },
    'high_precision_signal': {
      AppLanguage.vi: 'Tín hiệu độ chính xác cao',
      AppLanguage.en: 'High precision signal',
    },
    'moving_time': {
      AppLanguage.vi: 'Thời gian di chuyển',
      AppLanguage.en: 'Moving time',
    },
    'rest_time': {
      AppLanguage.vi: 'Thời gian nghỉ',
      AppLanguage.en: 'Rest time',
    },
    'back_to_history': {
      AppLanguage.vi: 'Về lịch sử tập',
      AppLanguage.en: 'Back to history',
    },
    'view_details': {
      AppLanguage.vi: 'Xem chi tiết',
      AppLanguage.en: 'View details',
    },
    'indoor_movement': {
      AppLanguage.vi: 'Chuyển động trong nhà',
      AppLanguage.en: 'Indoor movement',
    },
    'route_recap': {
      AppLanguage.vi: 'Tóm tắt lộ trình',
      AppLanguage.en: 'Route recap',
    },
    'session_time': {
      AppLanguage.vi: 'Thời gian tập',
      AppLanguage.en: 'Session time',
    },
    'saving': {
      AppLanguage.vi: 'Đang lưu...',
      AppLanguage.en: 'Saving...',
    },
    'recording_save_failed': {
      AppLanguage.vi: 'Chưa lưu được buổi tập',
      AppLanguage.en: 'Workout not saved',
    },
    'recording_save_retry_message': {
      AppLanguage.vi:
          'Buổi tập đã dừng nhưng chưa được xác nhận lưu. Dữ liệu cuối vẫn còn trong bộ nhớ ứng dụng. Hãy thử lưu lại và không đóng ứng dụng.',
      AppLanguage.en:
          'Recording has stopped, but the save has not been confirmed. The final workout is still in app memory. Retry and do not close the app.',
    },
    'recording_retry_save': {
      AppLanguage.vi: 'Thử lưu lại',
      AppLanguage.en: 'Retry save',
    },
    'recording_other_owner': {
      AppLanguage.vi: 'Có buổi tập chưa lưu của tài khoản khác. Đăng nhập lại tài khoản đó để thử lưu.',
      AppLanguage.en: 'An unsaved workout belongs to another account. Sign back into that account to retry.',
    },
    'recording_save_failed': {
      AppLanguage.vi: 'Chưa lưu được buổi tập',
      AppLanguage.en: 'Workout not saved',
    },
    'recording_save_retry_message': {
      AppLanguage.vi:
          'Buổi tập đã dừng nhưng chưa được xác nhận lưu. Dữ liệu cuối vẫn còn trong bộ nhớ ứng dụng. Hãy thử lưu lại và không đóng ứng dụng.',
      AppLanguage.en:
          'Recording has stopped, but the save has not been confirmed. The final workout is still in app memory. Retry and do not close the app.',
    },
    'recording_retry_save': {
      AppLanguage.vi: 'Thử lưu lại',
      AppLanguage.en: 'Retry save',
    },
    'recording_other_owner': {
      AppLanguage.vi: 'Có buổi tập chưa lưu của tài khoản khác. Đăng nhập lại tài khoản đó để thử lưu.',
      AppLanguage.en: 'An unsaved workout belongs to another account. Sign back into that account to retry.',
    },
    'auto_pause': {
      AppLanguage.vi: 'Tự động tạm dừng',
      AppLanguage.en: 'Auto pause',
    },
    'dist': {
      AppLanguage.vi: 'K.cách',
      AppLanguage.en: 'Dist',
    },
    'core_stats': {
      AppLanguage.vi: 'Chỉ số chính',
      AppLanguage.en: 'Core stats',
    },
    'performance': {
      AppLanguage.vi: 'Hiệu suất',
      AppLanguage.en: 'Performance',
    },
    'latest_split': {
      AppLanguage.vi: 'Tách vòng mới nhất',
      AppLanguage.en: 'Latest split',
    },
    'lap_splits': {
      AppLanguage.vi: 'Các mốc tách vòng',
      AppLanguage.en: 'Lap splits',
    },
    'details': {
      AppLanguage.vi: 'Chi tiết',
      AppLanguage.en: 'Details',
    },
    'calorie_goal': {
      AppLanguage.vi: 'Mục tiêu calo',
      AppLanguage.en: 'Calorie goal',
    },
    'workout_goal': {
      AppLanguage.vi: 'Mục tiêu bài tập',
      AppLanguage.en: 'Workout goal',
    },
    'distance_goal': {
      AppLanguage.vi: 'Mục tiêu khoảng cách',
      AppLanguage.en: 'Distance goal',
    },
    'completion': {
      AppLanguage.vi: 'Hoàn thành',
      AppLanguage.en: 'Completion',
    },

    // Header & Settings
    'settings': {AppLanguage.vi: 'Cài đặt', AppLanguage.en: 'Settings'},
    'account': {AppLanguage.vi: 'Tài khoản', AppLanguage.en: 'Account'},
    'workout_reminders': {
      AppLanguage.vi: 'Nhắc nhở tập luyện',
      AppLanguage.en: 'Workout reminders',
    },
    'daily_reminder': {
      AppLanguage.vi: 'Nhắc nhở tập chạy hàng ngày',
      AppLanguage.en: 'Daily run reminder',
    },
    'personalized_reminders': {
      AppLanguage.vi: 'Nhắc nhở thông minh',
      AppLanguage.en: 'Personalized reminders',
    },
    'personalized_subtitle': {
      AppLanguage.vi:
          'Tự động gợi ý dựa trên thói quen tập luyện của bạn.',
      AppLanguage.en:
          'We learn your routine and only send a nudge when it is useful.',
    },
    'app_preferences': {
      AppLanguage.vi: 'Cấu hình ứng dụng',
      AppLanguage.en: 'App preferences',
    },
    'app_language': {
      AppLanguage.vi: 'Ngôn ngữ ứng dụng',
      AppLanguage.en: 'App language',
    },
    'units': {AppLanguage.vi: 'Đơn vị đo', AppLanguage.en: 'Units'},
    'privacy_access': {
      AppLanguage.vi: 'Quyền riêng tư & truy cập',
      AppLanguage.en: 'Privacy access',
    },
    'camera_access': {
      AppLanguage.vi: 'Quyền truy cập Camera',
      AppLanguage.en: 'Camera access',
    },
    'photo_access': {
      AppLanguage.vi: 'Quyền truy cập Thư viện ảnh',
      AppLanguage.en: 'Photo library access',
    },
    'location_access': {
      AppLanguage.vi: 'Quyền truy cập Vị trí (GPS)',
      AppLanguage.en: 'Location access',
    },
    'data': {AppLanguage.vi: 'Dữ liệu & bảo mật', AppLanguage.en: 'Data & security'},
    'clear_cache': {
      AppLanguage.vi: 'Xóa bộ nhớ tạm (Cache)',
      AppLanguage.en: 'Clear cache',
    },
    'delete_account': {
      AppLanguage.vi: 'Xóa tài khoản vĩnh viễn',
      AppLanguage.en: 'Delete account',
    },
    'delete_account_subtitle': {
      AppLanguage.vi:
          'Xóa vĩnh viễn tài khoản, mục tiêu và dữ liệu tập luyện.',
      AppLanguage.en: 'Permanently remove your account and synced data',
    },
    'about_legal': {
      AppLanguage.vi: 'Về ứng dụng & pháp lý',
      AppLanguage.en: 'About & legal',
    },
    'version': {AppLanguage.vi: 'Phiên bản', AppLanguage.en: 'Version'},
    'terms_of_service': {
      AppLanguage.vi: 'Điều khoản sử dụng',
      AppLanguage.en: 'Terms of service',
    },
    'privacy_policy': {
      AppLanguage.vi: 'Chính sách bảo mật',
      AppLanguage.en: 'Privacy policy',
    },
    'data_compliance': {
      AppLanguage.vi: 'Dữ liệu & tuân thủ',
      AppLanguage.en: 'Data & compliance',
    },
    'intellectual_property': {
      AppLanguage.vi: 'Sở hữu trí tuệ',
      AppLanguage.en: 'Intellectual property',
    },
    'logout': {AppLanguage.vi: 'Đăng xuất', AppLanguage.en: 'Logout'},
    'logout_confirm_title': {
      AppLanguage.vi: 'Xác nhận đăng xuất',
      AppLanguage.en: 'Log out',
    },
    'logout_confirm_msg': {
      AppLanguage.vi:
          'Bạn có thể đăng nhập lại bất kỳ lúc nào để truy cập dữ liệu của mình.',
      AppLanguage.en:
          'You can sign back in at any time to return to your data.',
    },
    'select_language': {
      AppLanguage.vi: 'Chọn ngôn ngữ ứng dụng',
      AppLanguage.en: 'Select app language',
    },
    'vietnamese': {AppLanguage.vi: 'Tiếng Việt', AppLanguage.en: 'Vietnamese'},
    'english': {AppLanguage.vi: 'Tiếng Anh', AppLanguage.en: 'English'},
    'back': {AppLanguage.vi: 'Quay lại', AppLanguage.en: 'Back'},
    'delete_account_confirm_title': {
      AppLanguage.vi: 'Xóa tài khoản vĩnh viễn?',
      AppLanguage.en: 'Permanently delete account?',
    },
    'delete_account_confirm_msg': {
      AppLanguage.vi:
          'Toàn bộ dữ liệu tập luyện, hồ sơ và mục tiêu của bạn sẽ bị xóa vĩnh viễn và không thể khôi phục. Hành động này không thể hoàn tác.',
      AppLanguage.en:
          'All your workout history, profile data and goals will be permanently deleted and cannot be recovered. This action cannot be undone.',
    },
    'delete_account_type_email': {
      AppLanguage.vi: 'Nhập email của bạn để xác nhận',
      AppLanguage.en: 'Type your email to confirm',
    },
    'delete_account_btn': {
      AppLanguage.vi: 'Xóa tài khoản',
      AppLanguage.en: 'Delete account',
    },
    'delete_account_success': {
      AppLanguage.vi: 'Tài khoản đã được xóa thành công.',
      AppLanguage.en: 'Account deleted successfully.',
    },
    'delete_account_error': {
      AppLanguage.vi: 'Xóa tài khoản thất bại. Vui lòng thử lại.',
      AppLanguage.en: 'Failed to delete account. Please try again.',
    },
    'danger_zone': {AppLanguage.vi: 'Vùng nguy hiểm', AppLanguage.en: 'Danger zone'},

    // Segmented Filters & Goal Types
    'filter_all': {AppLanguage.vi: 'Tất cả', AppLanguage.en: 'All'},
    'filter_week': {AppLanguage.vi: 'Tuần', AppLanguage.en: 'Week'},
    'filter_month': {AppLanguage.vi: 'Tháng', AppLanguage.en: 'Month'},
    'filter_year': {AppLanguage.vi: 'Năm', AppLanguage.en: 'Year'},
    'goal_type_distance': {AppLanguage.vi: 'Quãng đường', AppLanguage.en: 'Distance'},
    'goal_type_workouts': {AppLanguage.vi: 'Bài tập', AppLanguage.en: 'Workouts'},
    'goal_type_calories': {AppLanguage.vi: 'Calo', AppLanguage.en: 'Calories'},

    // Live Workout & Telemetry
    'live_stats': {AppLanguage.vi: 'Dữ liệu trực tiếp', AppLanguage.en: 'Live telemetry'},
    'hold_to_finish': {AppLanguage.vi: 'Giữ để hoàn thành', AppLanguage.en: 'Hold to finish'},
    'discard_workout': {AppLanguage.vi: 'Hủy buổi tập', AppLanguage.en: 'Discard workout'},
    'confirm_discard_title': {
      AppLanguage.vi: 'Hủy buổi tập này?',
      AppLanguage.en: 'Discard this workout?',
    },
    'confirm_discard_msg': {
      AppLanguage.vi: 'Dữ liệu buổi tập hiện tại chưa được lưu và sẽ bị xóa.',
      AppLanguage.en: 'Current workout data has not been saved and will be lost.',
    },
    'keep_workout': {AppLanguage.vi: 'Tiếp tục tập', AppLanguage.en: 'Keep workout'},
    'yes_discard': {AppLanguage.vi: 'Đồng ý hủy', AppLanguage.en: 'Discard'},

    // Profile & Personal Records
    'personal_best': {AppLanguage.vi: 'Thành tích tốt nhất', AppLanguage.en: 'Personal best'},
    'total_duration': {AppLanguage.vi: 'Tổng thời lượng', AppLanguage.en: 'Total duration'},
    'total_calories': {AppLanguage.vi: 'Tổng calo', AppLanguage.en: 'Total calories'},
    'current_pace': {AppLanguage.vi: 'Nhịp độ hiện tại', AppLanguage.en: 'Current pace'},
    'gps_accuracy': {AppLanguage.vi: 'Độ chính xác GPS', AppLanguage.en: 'GPS accuracy'},

    // Settings & Legal Subtitles
    'legal_and_support': {AppLanguage.vi: 'Pháp lý & hỗ trợ', AppLanguage.en: 'Legal & support'},
    'daily_notifications': {
      AppLanguage.vi: 'Bật/Tắt nhắc nhở tập luyện & mục tiêu',
      AppLanguage.en: 'Receive workout reminders & goal alerts',
    },
    'open_source_licenses': {
      AppLanguage.vi: 'Giấy phép nguồn mở',
      AppLanguage.en: 'Open source licenses',
    },
    'open_source_sub': {
      AppLanguage.vi: 'Phần mềm bên thứ ba được sử dụng trong Aetron',
      AppLanguage.en: 'Third-party software used by Aetron',
    },
    'help_and_support': {
      AppLanguage.vi: 'Trợ giúp & hỗ trợ',
      AppLanguage.en: 'Help & support',
    },
    'help_and_support_sub': {
      AppLanguage.vi: 'Nhận trợ giúp và giải đáp thắc mắc về Aetron',
      AppLanguage.en: 'Get help with Aetron',
    },
    'privacy_sub': {
      AppLanguage.vi: 'Cách Aetron thu thập, sử dụng và bảo vệ dữ liệu của bạn',
      AppLanguage.en: 'How Aetron collects, uses and protects your data',
    },
    'terms_sub': {
      AppLanguage.vi: 'Các quy định và điều kiện khi sử dụng Aetron',
      AppLanguage.en: 'Rules and conditions for using Aetron',
    },
  };

  static String get(String key, AppLanguage lang) {
    final translation = _keys[key]?[lang] ?? _keys[key]?[AppLanguage.en];
    if (translation != null) return translation;
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
