class AcademicService {
  static final AcademicService _instance = AcademicService._internal();
  factory AcademicService() => _instance;
  AcademicService._internal();

  static const List<String> departments = [
    "Computer Science",
    "Software Engineering",
    "Information Technology",
    "Electrical Engineering",
    "Mechanical Engineering",
    "Civil Engineering",
    "Business Administration",
    "Mathematics",
    "Physics",
    "Chemistry",
    "Biology",
    "Psychology",
    "Economics",
    "English Literature",
    "Media Studies",
  ];

  List<String> getCoursesForDepartment(String department) {
    final dept = department.trim().toLowerCase();
    if (dept.contains('computer science') || dept == 'cs') {
      return [
        'BSCS (Bachelor of Computer Science) - 4 Years',
        'MSCS (Master of Computer Science) - 2 Years',
        'PhD Computer Science - 5 Years',
      ];
    } else if (dept.contains('software engineering') || dept == 'se') {
      return [
        'BSSE (Bachelor of Software Engineering) - 4 Years',
        'MSSE (Master of Software Engineering) - 2 Years',
        'PhD Software Engineering - 5 Years',
      ];
    } else if (dept.contains('information technology') || dept == 'it') {
      return [
        'BSIT (Bachelor of Information Technology) - 4 Years',
        'MSIT (Master of Information Technology) - 2 Years',
        'PhD IT - 5 Years',
      ];
    } else if (dept.contains('electrical')) {
      return [
        'BSEE (Bachelor of Electrical Engineering) - 4 Years',
        'MSEE (Master of Electrical Engineering) - 2 Years',
        'PhD Electrical Engineering - 5 Years',
      ];
    } else if (dept.contains('business')) {
      return [
        'BBA (Bachelor of Business Administration) - 4 Years',
        'MBA (Master of Business Administration) - 2 Years',
        'MS Management Sciences - 2 Years',
      ];
    } else {
      return [
        'Bachelor Degree Program - 4 Years',
        'Master Degree Program - 2 Years',
        'PhD Doctoral Program - 5 Years',
      ];
    }
  }

  List<String> generateBatches(String selectedCourse) {
    final int currentYear = DateTime.now().year;
    final Set<String> uniqueBatches = {};

    int duration = 4;
    if (selectedCourse.contains('Master') ||
        selectedCourse.contains('MSCS') ||
        selectedCourse.contains('MSSE') ||
        selectedCourse.contains('MSIT') ||
        selectedCourse.contains('MBA') ||
        selectedCourse.contains('2 Years')) {
      duration = 2;
    } else if (selectedCourse.contains('PhD') ||
        selectedCourse.contains('Doctoral') ||
        selectedCourse.contains('5 Years')) {
      duration = 5;
    }

    for (int i = 0; i < duration + 1; i++) {
      int batchYear = currentYear - i;
      uniqueBatches.add('Batch $batchYear - ${batchYear + duration}');
    }

    final list = uniqueBatches.toList();
    list.sort();
    return list;
  }

  List<String> generateSemesters(String selectedCourse) {
    int totalSemesters = 8;
    if (selectedCourse.contains('Master') ||
        selectedCourse.contains('MSCS') ||
        selectedCourse.contains('MSSE') ||
        selectedCourse.contains('MSIT') ||
        selectedCourse.contains('MBA') ||
        selectedCourse.contains('2 Years')) {
      totalSemesters = 4;
    } else if (selectedCourse.contains('PhD') ||
        selectedCourse.contains('Doctoral') ||
        selectedCourse.contains('5 Years')) {
      totalSemesters = 10;
    }

    return List.generate(totalSemesters, (index) => 'Semester ${index + 1}');
  }

  List<String> getSubjects({
    required String department,
    required String selectedCourse,
  }) {
    final dept = department.trim().toLowerCase();
    final Set<String> uniqueSubjects = {};

    if (dept.contains('computer science') || dept == 'cs') {
      if (selectedCourse.contains('Master') || selectedCourse.contains('MSCS')) {
        uniqueSubjects.addAll([
          'Advanced Algorithms',
          'Advanced Database Systems',
          'Research Methodology',
          'Advanced Operating Systems',
          'Advanced Computer Networks',
          'Machine Learning',
          'Data Science',
          'Big Data Analytics',
          'Cloud Computing',
          'Network Security',
          'Artificial Intelligence',
          'Thesis Part 1',
          'Thesis Part 2',
        ]);
      } else if (selectedCourse.contains('PhD')) {
        uniqueSubjects.addAll([
          'Advanced Research Methods',
          'PhD Seminar',
          'Dissertation Research',
          'Advanced Topics in CS',
          'Research Publication',
        ]);
      } else {
        uniqueSubjects.addAll([
          'Programming Fundamentals',
          'Object Oriented Programming',
          'Data Structures & Algorithms',
          'Database Systems',
          'Operating Systems',
          'Software Engineering',
          'Computer Networks',
          'Artificial Intelligence',
          'Web Engineering',
          'Mobile App Development',
          'Information Security',
          'Theory of Automata',
          'Cloud Computing',
          'Design & Analysis of Algorithms',
          'Human Computer Interaction',
          'Linear Algebra',
          'Calculus & Analytical Geometry',
          'Discrete Structures',
          'Digital Logic Design',
          'Final Year Project Part 1',
          'Final Year Project Part 2',
        ]);
      }
    } else if (dept.contains('software engineering') || dept == 'se') {
      uniqueSubjects.addAll([
        'Programming Fundamentals',
        'Object Oriented Programming',
        'Data Structures',
        'Database Systems',
        'Software Requirements Engineering',
        'Software Design & Architecture',
        'Software Testing & QA',
        'Software Project Management',
        'Web Engineering',
        'Mobile App Development',
        'Cloud Computing',
        'DevOps & CI/CD',
        'Agile Software Development',
        'User Experience Design',
        'Software Metrics',
        'Final Year Project',
      ]);
    } else if (dept.contains('information technology') || dept == 'it') {
      uniqueSubjects.addAll([
        'IT Fundamentals',
        'Programming Basics',
        'Web Technologies',
        'Database Management',
        'Network Administration',
        'System Administration',
        'IT Project Management',
        'Cyber Security',
        'Cloud Infrastructure',
        'E-commerce Technologies',
        'Data Analytics',
        'Final Year Project',
      ]);
    } else if (dept.contains('business')) {
      uniqueSubjects.addAll([
        'Principles of Management',
        'Financial Accounting',
        'Marketing Management',
        'Business Communication',
        'Human Resource Management',
        'Business Statistics',
        'Financial Management',
        'Strategic Management',
        'Entrepreneurship',
        'Organizational Behavior',
      ]);
    } else {
      uniqueSubjects.addAll([
        'Introduction to Course',
        'Foundational Theory',
        'Applied Concepts',
        'Research Methodology',
        'Advanced Topic I',
        'Advanced Topic II',
        'Seminar & Presentations',
        'Final Project',
      ]);
    }

    final result = uniqueSubjects.toList();
    result.sort();
    return result;
  }
}
