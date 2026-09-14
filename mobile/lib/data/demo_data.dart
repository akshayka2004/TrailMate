// Bundled demo campus dataset — used only when the backend is unreachable
// AND no synced cache exists yet (e.g. a fresh install with no live DB
// connected). Mirrors the backend seed data (same names/coordinates) so the
// app is fully demoable standalone. Remove reliance on this once the
// backend + database are live and reachable from first launch.

const String kDemoEmail = 'admin@trailmate.dev';
const String kDemoPassword = 'Admin@123';
const String kDemoToken = 'demo-local-token';

final Map<String, dynamic> kDemoSnapshot = {
  'version': 0,
  'graph': {
    'buildings': [
      {'id': 1, 'name': 'Admin Block', 'description': "Administration, principal's office, accounts.", 'lat': 9.5133, 'lng': 76.5421},
      {'id': 2, 'name': 'CS Block', 'description': 'Computer Science & Engineering department.', 'lat': 9.5138, 'lng': 76.5428},
      {'id': 3, 'name': 'Mechanical Block', 'description': 'Mechanical Engineering department and workshops.', 'lat': 9.5127, 'lng': 76.5432},
      {'id': 4, 'name': 'Central Library', 'description': 'Library and reading halls.', 'lat': 9.5136, 'lng': 76.5415},
    ],
    'departments': [
      {'id': 1, 'name': 'Computer Science & Engineering', 'building_id': 2},
      {'id': 2, 'name': 'Mechanical Engineering', 'building_id': 3},
      {'id': 3, 'name': 'Administration', 'building_id': 1},
    ],
    'rooms': [
      {'id': 1, 'name': 'CS-101', 'type': 'classroom', 'floor': 1, 'building_id': 2},
      {'id': 2, 'name': 'Programming Lab 1', 'type': 'lab', 'floor': 1, 'building_id': 2},
      {'id': 3, 'name': 'CS Seminar Hall', 'type': 'seminar_hall', 'floor': 2, 'building_id': 2},
      {'id': 4, 'name': "Principal's Office", 'type': 'office', 'floor': 1, 'building_id': 1},
      {'id': 5, 'name': 'CAD Lab', 'type': 'lab', 'floor': 1, 'building_id': 3},
      {'id': 6, 'name': 'Reading Hall', 'type': 'classroom', 'floor': 1, 'building_id': 4},
    ],
    'checkpoints': [
      {'id': 1, 'label': 'Main Gate', 'lat': 9.5125, 'lng': 76.5410, 'building_id': null},
      {'id': 2, 'label': 'Junction A (flagpole)', 'lat': 9.5130, 'lng': 76.5416, 'building_id': null},
      {'id': 3, 'label': 'Junction B (canteen turn)', 'lat': 9.5132, 'lng': 76.5425, 'building_id': null},
      {'id': 4, 'label': 'Junction C (workshop road)', 'lat': 9.5128, 'lng': 76.5430, 'building_id': null},
      {'id': 5, 'label': 'Parking Lot', 'lat': 9.5123, 'lng': 76.5414, 'building_id': null},
      {'id': 6, 'label': 'Admin Block Entrance', 'lat': 9.5133, 'lng': 76.5420, 'building_id': 1},
      {'id': 7, 'label': 'Admin Lobby', 'lat': 9.51335, 'lng': 76.5422, 'building_id': 1},
      {'id': 8, 'label': 'CS Block Entrance', 'lat': 9.5137, 'lng': 76.5427, 'building_id': 2},
      {'id': 9, 'label': 'CS Stairwell (Ground)', 'lat': 9.5138, 'lng': 76.5429, 'building_id': 2},
      {'id': 10, 'label': 'CS Floor 2 Corridor', 'lat': 9.51382, 'lng': 76.54292, 'building_id': 2},
      {'id': 11, 'label': 'Mechanical Block Entrance', 'lat': 9.5127, 'lng': 76.5431, 'building_id': 3},
      {'id': 12, 'label': 'Workshop Bay', 'lat': 9.5126, 'lng': 76.5433, 'building_id': 3},
      {'id': 13, 'label': 'Library Entrance', 'lat': 9.5135, 'lng': 76.5416, 'building_id': 4},
      {'id': 14, 'label': 'Reading Hall Door', 'lat': 9.5136, 'lng': 76.5414, 'building_id': 4},
      {'id': 15, 'label': 'Canteen', 'lat': 9.5134, 'lng': 76.5424, 'building_id': null},
    ],
    'edges': [
      {'checkpoint_a_id': 1, 'checkpoint_b_id': 2, 'distance_meters': 85.0, 'walking_time_estimate_sec': 60},
      {'checkpoint_a_id': 1, 'checkpoint_b_id': 5, 'distance_meters': 60.0, 'walking_time_estimate_sec': 42},
      {'checkpoint_a_id': 2, 'checkpoint_b_id': 3, 'distance_meters': 100.0, 'walking_time_estimate_sec': 71},
      {'checkpoint_a_id': 3, 'checkpoint_b_id': 4, 'distance_meters': 70.0, 'walking_time_estimate_sec': 50},
      {'checkpoint_a_id': 2, 'checkpoint_b_id': 13, 'distance_meters': 55.0, 'walking_time_estimate_sec': 39},
      {'checkpoint_a_id': 2, 'checkpoint_b_id': 6, 'distance_meters': 50.0, 'walking_time_estimate_sec': 35},
      {'checkpoint_a_id': 3, 'checkpoint_b_id': 8, 'distance_meters': 45.0, 'walking_time_estimate_sec': 32},
      {'checkpoint_a_id': 3, 'checkpoint_b_id': 15, 'distance_meters': 30.0, 'walking_time_estimate_sec': 21},
      {'checkpoint_a_id': 4, 'checkpoint_b_id': 11, 'distance_meters': 25.0, 'walking_time_estimate_sec': 17},
      {'checkpoint_a_id': 6, 'checkpoint_b_id': 7, 'distance_meters': 15.0, 'walking_time_estimate_sec': 10, 'is_indoor': true},
      {'checkpoint_a_id': 8, 'checkpoint_b_id': 9, 'distance_meters': 20.0, 'walking_time_estimate_sec': 14, 'is_indoor': true},
      {'checkpoint_a_id': 9, 'checkpoint_b_id': 10, 'distance_meters': 12.0, 'walking_time_estimate_sec': 8, 'is_indoor': true},
      {'checkpoint_a_id': 11, 'checkpoint_b_id': 12, 'distance_meters': 30.0, 'walking_time_estimate_sec': 21, 'is_indoor': true},
      {'checkpoint_a_id': 13, 'checkpoint_b_id': 14, 'distance_meters': 18.0, 'walking_time_estimate_sec': 12, 'is_indoor': true},
      {'checkpoint_a_id': 15, 'checkpoint_b_id': 8, 'distance_meters': 40.0, 'walking_time_estimate_sec': 28},
      {'checkpoint_a_id': 5, 'checkpoint_b_id': 2, 'distance_meters': 70.0, 'walking_time_estimate_sec': 50},
    ],
  },
};
