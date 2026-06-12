import 'package:flutter/material.dart';

class ServiceCategory {
  final String id;
  final String name;
  final String nameHi;
  final String emoji;
  final IconData icon;
  final Color color;
  final String description;
  final String descriptionHi;
  final String longDescription;
  final String longDescriptionHi;
  final List<SubService> subServices;
  final List<String> features;
  final String whatsappNumber;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.nameHi,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.description,
    required this.descriptionHi,
    required this.longDescription,
    required this.longDescriptionHi,
    required this.subServices,
    required this.features,
    this.whatsappNumber = '918586040076',
  });
}

class SubService {
  final String name;
  final String nameHi;
  final String description;
  final String descriptionHi;
  final String priceRange;
  final IconData icon;

  const SubService({
    required this.name,
    required this.nameHi,
    required this.description,
    required this.descriptionHi,
    required this.priceRange,
    required this.icon,
  });
}

class ServicesRepository {
  static List<ServiceCategory> getAllCategories() {
    return [
      ServiceCategory(
        id: 'home_cleaning',
        name: 'Home Cleaning',
        nameHi: 'घर की सफाई',
        emoji: '🧹',
        icon: Icons.cleaning_services_rounded,
        color: const Color(0xFF00BCD4),
        description: 'Deep cleaning, sanitization & washing.',
        descriptionHi: 'डीप क्लीनिंग, सैनिटाइजेशन और धुलाई।',
        longDescription: 'Get your entire house sparkling clean with our professional deep cleaning services. We use eco-friendly chemicals and trained staff to remove stubborn stains and germs from every corner.',
        longDescriptionHi: 'हमारे पेशेवर डीप क्लीनिंग सेवा के साथ अपने पूरे घर को चमकाएं। हम जिद्दी दाग और कीटाणुओं को हटाने के लिए पर्यावरण के अनुकूल रसायनों और प्रशिक्षित कर्मचारियों का उपयोग करते हैं।',
        features: ['Eco-Friendly', 'Trained Staff', '100% Satisfaction'],
        subServices: [
          const SubService(
            name: 'Full Home Deep Clean', nameHi: 'फुल होम डीप क्लीन',
            description: 'Intensive cleaning of all rooms, bathrooms & kitchen.',
            descriptionHi: 'सभी कमरों, बाथरूम और रसोई की गहन सफाई।',
            priceRange: '₹1500 - ₹5000', icon: Icons.house_rounded,
          ),
          const SubService(
            name: 'Bathroom Cleaning', nameHi: 'बाथरूम की सफाई',
            description: 'Hard water stains removal and tile scrubbing.',
            descriptionHi: 'खारे पानी के दाग हटाना और टाइल्स की घिसाई।',
            priceRange: '₹400 - ₹999', icon: Icons.bathtub_rounded,
          ),
          const SubService(
            name: 'Sofa Cleaning', nameHi: 'सोफा की सफाई',
            description: 'Vacuuming and shampooing of fabric sofas.',
            descriptionHi: 'फैब्रिक सोफे की वैक्यूमिंग और शैंपू से धुलाई।',
            priceRange: '₹300 / Seat', icon: Icons.weekend_rounded,
          ),
        ],
      ),
      ServiceCategory(
        id: 'electrician',
        name: 'Electrician',
        nameHi: 'बिजली मिस्त्री',
        emoji: '💡',
        icon: Icons.electrical_services_rounded,
        color: const Color(0xFFFFC107),
        description: 'Wiring, switches, appliances repair.',
        descriptionHi: 'वायरिंग, स्विच और उपकरणों की मरम्मत।',
        longDescription: 'Expert electricians for all your electrical needs. From fixing a simple short circuit to complete home wiring, inverter installation, and fan/light fitting, we do it safely and professionally.',
        longDescriptionHi: 'आपकी सभी बिजली की जरूरतों के लिए विशेषज्ञ इलेक्ट्रीशियन। शॉर्ट सर्किट ठीक करने से लेकर पूरी होम वायरिंग, इन्वर्टर इंस्टालेशन और पंखा/लाइट फिटिंग तक, हम सुरक्षित रूप से काम करते हैं।',
        features: ['Licensed Pros', 'Safety First', 'Quick Repair'],
        subServices: [
          const SubService(
            name: 'Switchboard Repair', nameHi: 'स्विचबोर्ड मरम्मत',
            description: 'Fixing or replacing old switchboards and sockets.',
            descriptionHi: 'पुराने स्विचबोर्ड और सॉकेट को ठीक करना या बदलना।',
            priceRange: '₹150 - ₹500', icon: Icons.power_rounded,
          ),
          const SubService(
            name: 'Fan/Light Fitting', nameHi: 'पंखा/लाइट फिटिंग',
            description: 'Installation of ceiling fans, tube lights, and chandeliers.',
            descriptionHi: 'छत के पंखे, ट्यूब लाइट और झूमर लगाना।',
            priceRange: '₹100 - ₹400', icon: Icons.lightbulb_rounded,
          ),
          const SubService(
            name: 'Inverter Setup', nameHi: 'इन्वर्टर सेटअप',
            description: 'Complete wiring and installation of inverter/battery.',
            descriptionHi: 'इन्वर्टर/बैटरी की पूरी वायरिंग और इंस्टालेशन।',
            priceRange: '₹500 - ₹1200', icon: Icons.battery_charging_full_rounded,
          ),
        ],
      ),
      ServiceCategory(
        id: 'plumber',
        name: 'Plumber',
        nameHi: 'प्लम्बर',
        emoji: '🔧',
        icon: Icons.plumbing_rounded,
        color: const Color(0xFF2196F3),
        description: 'Pipe leaks, taps & bathroom fittings.',
        descriptionHi: 'पाइप लीकेज, नल और बाथरूम फिटिंग।',
        longDescription: 'Professional plumbing services to solve water leakages, blockages, and new fittings. We install water tanks, fix broken pipes, and repair bathroom sanitary wares efficiently.',
        longDescriptionHi: 'पानी के लीकेज, ब्लॉकेज और नई फिटिंग को हल करने के लिए पेशेवर प्लंबिंग सेवाएं। हम पानी की टंकी लगाते हैं, टूटे हुए पाइप ठीक करते हैं और सैनिटरी वेयर की मरम्मत करते हैं।',
        features: ['No Hidden Costs', 'Fast Service', 'Quality Parts'],
        subServices: [
          const SubService(
            name: 'Tap/Mixer Repair', nameHi: 'नल/मिक्सर मरम्मत',
            description: 'Fixing dripping taps and installing new washbasin mixers.',
            descriptionHi: 'टपकते नलों को ठीक करना और नए मिक्सर लगाना।',
            priceRange: '₹150 - ₹600', icon: Icons.water_drop_rounded,
          ),
          const SubService(
            name: 'Drain Blockage', nameHi: 'नाली ब्लॉकेज',
            description: 'Clearing choked kitchen sinks and bathroom drains.',
            descriptionHi: 'जाम हुए किचन सिंक और बाथरूम की नाली को साफ करना।',
            priceRange: '₹300 - ₹1000', icon: Icons.water_damage_rounded,
          ),
          const SubService(
            name: 'Water Tank Install', nameHi: 'पानी की टंकी लगाना',
            description: 'New water tank fitting with proper pipe connections.',
            descriptionHi: 'उचित पाइप कनेक्शन के साथ नई पानी की टंकी की फिटिंग।',
            priceRange: '₹800 - ₹2500', icon: Icons.propane_tank_rounded,
          ),
        ],
      ),
      ServiceCategory(
        id: 'carpenter',
        name: 'Carpenter',
        nameHi: 'बढ़ई (कारपेंटर)',
        emoji: '🪚',
        icon: Icons.carpenter_rounded,
        color: const Color(0xFF795548),
        description: 'Furniture repair, doors & custom work.',
        descriptionHi: 'फर्नीचर मरम्मत, दरवाजे और कस्टम काम।',
        longDescription: 'Skilled carpentry services for repairing broken furniture, installing wooden doors/windows, making custom wardrobes, and modular kitchen setups using premium wood and ply.',
        longDescriptionHi: 'टूटे हुए फर्नीचर की मरम्मत, लकड़ी के दरवाजे/खिड़कियां लगाने, कस्टम अलमारी बनाने और प्रीमियम लकड़ी से मॉड्यूलर किचन सेटअप के लिए कुशल बढ़ई सेवाएं।',
        features: ['Premium Finish', 'Custom Designs', 'Durable Woodwork'],
        subServices: [
          const SubService(
            name: 'Door/Window Repair', nameHi: 'दरवाजा/खिड़की मरम्मत',
            description: 'Fixing hinges, locks, and alignment issues.',
            descriptionHi: 'कब्जे, ताले और फिटिंग की समस्याओं को ठीक करना।',
            priceRange: '₹200 - ₹800', icon: Icons.door_front_door_rounded,
          ),
          const SubService(
            name: 'Custom Wardrobe', nameHi: 'कस्टम अलमारी',
            description: 'Building new wooden wardrobes as per your room size.',
            descriptionHi: 'आपके कमरे के आकार के अनुसार नई लकड़ी की अलमारी बनाना।',
            priceRange: '₹5000+', icon: Icons.checkroom_rounded,
          ),
          const SubService(
            name: 'Furniture Repair', nameHi: 'फर्नीचर मरम्मत',
            description: 'Repairing broken chairs, tables, and wooden beds.',
            descriptionHi: 'टूटी हुई कुर्सियों, मेजों और लकड़ी के बेड की मरम्मत।',
            priceRange: '₹300 - ₹1500', icon: Icons.chair_rounded,
          ),
        ],
      ),
      ServiceCategory(
        id: 'ac_repair',
        name: 'AC Repair',
        nameHi: 'एसी मरम्मत',
        emoji: '❄️',
        icon: Icons.ac_unit_rounded,
        color: const Color(0xFF03A9F4),
        description: 'AC service, gas refill & installation.',
        descriptionHi: 'एसी सर्विस, गैस रिफिल और इंस्टालेशन।',
        longDescription: 'Stay cool with our expert AC repair services. We provide thorough deep cleaning, accurate gas pressure checks, PCB repairing, and seamless installation for both Window and Split ACs.',
        longDescriptionHi: 'हमारी विशेषज्ञ एसी मरम्मत सेवाओं के साथ ठंडे रहें। हम विंडो और स्प्लिट एसी दोनों के लिए डीप क्लीनिंग, गैस प्रेशर चेक, पीसीबी मरम्मत और बेहतरीन इंस्टालेशन प्रदान करते हैं।',
        features: ['90-Day Warranty', 'Genuine Gas', 'Deep Clean'],
        subServices: [
          const SubService(
            name: 'AC Servicing', nameHi: 'एसी सर्विसिंग',
            description: 'Jet pump cleaning of filters, coils, and outdoor unit.',
            descriptionHi: 'फिल्टर, कॉइल और आउटडोर यूनिट की जेट पंप से सफाई।',
            priceRange: '₹499 - ₹799', icon: Icons.air_rounded,
          ),
          const SubService(
            name: 'Gas Refill', nameHi: 'गैस रिफिल',
            description: 'Leakage fixing and topping up AC cooling gas.',
            descriptionHi: 'लीकेज ठीक करना और एसी की कूलिंग गैस भरना।',
            priceRange: '₹1500 - ₹2500', icon: Icons.speed_rounded,
          ),
          const SubService(
            name: 'AC Install/Uninstall', nameHi: 'एसी लगाना/उतारना',
            description: 'Safe mounting or removal of Split/Window AC units.',
            descriptionHi: 'स्प्लिट/विंडो एसी यूनिट को सुरक्षित रूप से लगाना या उतारना।',
            priceRange: '₹600 - ₹1500', icon: Icons.move_to_inbox_rounded,
          ),
        ],
      ),
      ServiceCategory(
        id: 'painter',
        name: 'Painter',
        nameHi: 'पेंटर (पुताई)',
        emoji: '🎨',
        icon: Icons.format_paint_rounded,
        color: const Color(0xFF9C27B0),
        description: 'Home painting, textures & waterproofing.',
        descriptionHi: 'घर की पुताई, टेक्सचर और वाटरप्रूफिंग।',
        longDescription: 'Transform your home with our premium painting services. We offer interior/exterior wall painting, beautiful textures, damp-proofing, and wood polishing with high-quality paints.',
        longDescriptionHi: 'हमारी प्रीमियम पेंटिंग सेवाओं के साथ अपने घर को बदलें। हम उच्च गुणवत्ता वाले पेंट के साथ आंतरिक/बाहरी दीवार पेंटिंग, सुंदर टेक्सचर, सीलन-रोधी और लकड़ी की पॉलिश प्रदान करते हैं।',
        features: ['Color Consult', 'Clean Execution', 'Premium Paint'],
        subServices: [
          const SubService(
            name: 'Interior Painting', nameHi: 'इंटीरियर पेंटिंग',
            description: 'Smooth finish wall painting for living rooms and bedrooms.',
            descriptionHi: 'लिविंग रूम और बेडरूम के लिए स्मूथ फिनिश वॉल पेंटिंग।',
            priceRange: '₹10 - ₹25 / sq.ft', icon: Icons.format_paint_rounded,
          ),
          const SubService(
            name: 'Waterproofing', nameHi: 'वाटरप्रूफिंग',
            description: 'Roof and wall dampness solutions to stop water leakage.',
            descriptionHi: 'पानी के रिसाव को रोकने के लिए छत और दीवार की सीलन का समाधान।',
            priceRange: '₹20 - ₹50 / sq.ft', icon: Icons.water_drop_rounded,
          ),
          const SubService(
            name: 'Wood Polish', nameHi: 'लकड़ी की पॉलिश',
            description: 'PU, Melamine, or normal polish for doors and furniture.',
            descriptionHi: 'दरवाजों और फर्नीचर के लिए पीयू, मेलामाइन या सामान्य पॉलिश।',
            priceRange: '₹30 - ₹80 / sq.ft', icon: Icons.chair_alt_rounded,
          ),
        ],
      ),
      ServiceCategory(
        id: 'welding',
        name: 'Welding',
        nameHi: 'वेल्डिंग का काम',
        emoji: '🔥',
        icon: Icons.hardware_rounded,
        color: const Color(0xFFFF5722),
        description: 'Iron gates, grills & fabrication work.',
        descriptionHi: 'लोहे के गेट, ग्रिल और फैब्रिकेशन का काम।',
        longDescription: 'Expert fabrication and welding services for manufacturing strong iron gates, window grills, balcony railings, and repairing broken metal structures securely.',
        longDescriptionHi: 'मजबूत लोहे के गेट, खिड़की की ग्रिल, बालकनी की रेलिंग बनाने और टूटे हुए धातु के ढांचे को सुरक्षित रूप से वेल्ड करने के लिए विशेषज्ञ फैब्रिकेशन सेवाएं।',
        features: ['Strong Joints', 'Custom Fabrication', 'Rust-proof Prime'],
        subServices: [
          const SubService(
            name: 'Iron Gate/Grill', nameHi: 'लोहे का गेट/ग्रिल',
            description: 'Making custom-designed safety doors and window grills.',
            descriptionHi: 'कस्टम-डिज़ाइन किए गए सुरक्षा द्वार और खिड़की की ग्रिल बनाना।',
            priceRange: '₹150 - ₹300 / sq.ft', icon: Icons.door_sliding_rounded,
          ),
          const SubService(
            name: 'Railing Work', nameHi: 'रेलिंग का काम',
            description: 'Staircase and balcony railing using MS or Steel.',
            descriptionHi: 'एमएस या स्टील का उपयोग करके सीढ़ी और बालकनी की रेलिंग।',
            priceRange: '₹300 - ₹800 / running ft', icon: Icons.fence_rounded,
          ),
          const SubService(
            name: 'Welding Repair', nameHi: 'वेल्डिंग मरम्मत',
            description: 'Spot welding and fixing broken metal joints on site.',
            descriptionHi: 'साइट पर टूटे हुए धातु के जोड़ों की वेल्डिंग और मरम्मत।',
            priceRange: '₹300 - ₹1000', icon: Icons.construction_rounded,
          ),
        ],
      ),
      ServiceCategory(
        id: 'appliance_repair',
        name: 'Appliances',
        nameHi: 'उपकरण मरम्मत',
        emoji: '📺',
        icon: Icons.kitchen_rounded,
        color: const Color(0xFF673AB7),
        description: 'Fridge, washing machine, TV repair.',
        descriptionHi: 'फ्रिज, वाशिंग मशीन, टीवी की मरम्मत।',
        longDescription: 'Get your broken home appliances running like new! We repair refrigerators, washing machines, microwaves, RO purifiers, and televisions at your doorstep with genuine spare parts.',
        longDescriptionHi: 'अपने खराब घरेलू उपकरणों को नए जैसा चलाएं! हम आपके घर पर असली स्पेयर पार्ट्स के साथ फ्रिज, वाशिंग मशीन, माइक्रोवेव, आरओ और टीवी की मरम्मत करते हैं।',
        features: ['Doorstep Service', 'Genuine Parts', 'All Brands'],
        subServices: [
          const SubService(
            name: 'Washing Machine', nameHi: 'वाशिंग मशीन',
            description: 'Repair for fully-automatic & semi-automatic machines.',
            descriptionHi: 'फुल-ऑटोमैटिक और सेमी-ऑटोमैटिक मशीनों की मरम्मत।',
            priceRange: '₹399 - ₹1500', icon: Icons.local_laundry_service_rounded,
          ),
          const SubService(
            name: 'Refrigerator', nameHi: 'फ्रिज (रेफ्रिजरेटर)',
            description: 'Gas filling, compressor check, and cooling issues.',
            descriptionHi: 'गैस भरना, कंप्रेसर चेक और कूलिंग की समस्याओं का समाधान।',
            priceRange: '₹499 - ₹2500', icon: Icons.kitchen_rounded,
          ),
          const SubService(
            name: 'RO Water Purifier', nameHi: 'आरओ वाटर प्यूरीफायर',
            description: 'Filter change, motor repair, and general service.',
            descriptionHi: 'फिल्टर बदलना, मोटर की मरम्मत और सामान्य सर्विस।',
            priceRange: '₹299 - ₹1200', icon: Icons.water_drop_rounded,
          ),
        ],
      ),
      ServiceCategory(
        id: 'packers',
        name: 'Packers & Movers',
        nameHi: 'पैकर्स एंड मूवर्स',
        emoji: '📦',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFFE91E63),
        description: 'Safe home and office shifting.',
        descriptionHi: 'सुरक्षित घर और ऑफिस शिफ्टिंग।',
        longDescription: 'Relocate without stress. We provide secure packing, careful loading, safe transportation, and unloading services for homes, offices, and individual heavy items.',
        longDescriptionHi: 'बिना तनाव के शिफ्ट करें। हम घरों, कार्यालयों और भारी सामानों के लिए सुरक्षित पैकिंग, लोडिंग, सुरक्षित परिवहन और अनलोडिंग सेवाएं प्रदान करते हैं।',
        features: ['Safe Packing', 'On-time Delivery', 'Careful Handling'],
        subServices: [
          const SubService(
            name: 'Home Relocation', nameHi: 'घर शिफ्टिंग',
            description: 'Complete shifting of 1BHK/2BHK/3BHK household items.',
            descriptionHi: '1BHK/2BHK/3BHK घरेलू सामानों की पूरी शिफ्टिंग।',
            priceRange: '₹3000 - ₹15000', icon: Icons.home_rounded,
          ),
          const SubService(
            name: 'Mini Truck / Tempo', nameHi: 'छोटा हाथी / टेम्पो',
            description: 'Hire a mini truck for moving few furniture pieces locally.',
            descriptionHi: 'स्थानीय रूप से कुछ फर्नीचर ले जाने के लिए मिनी ट्रक किराए पर लें।',
            priceRange: '₹500 - ₹2000', icon: Icons.airport_shuttle_rounded,
          ),
        ],
      ),
      ServiceCategory(
        id: 'tutor',
        name: 'Home Tutor',
        nameHi: 'होम ट्यूशन',
        emoji: '📚',
        icon: Icons.school_rounded,
        color: const Color(0xFF3F51B5),
        description: 'Maths, Science, English classes.',
        descriptionHi: 'गणित, विज्ञान, अंग्रेजी की कक्षाएं।',
        longDescription: 'Empower your child’s education with experienced home tutors. We offer personalized coaching for all school subjects, competitive exams, and spoken English right at your home.',
        longDescriptionHi: 'अनुभवी होम ट्यूटर्स के साथ अपने बच्चे की शिक्षा को सशक्त बनाएं। हम आपके घर पर ही स्कूल के सभी विषयों, प्रतियोगी परीक्षाओं और स्पोकन इंग्लिश के लिए कोचिंग देते हैं।',
        features: ['Expert Teachers', 'Flexible Timings', 'Demo Class'],
        subServices: [
          const SubService(
            name: 'Class 1 to 10', nameHi: 'कक्षा 1 से 10',
            description: 'All subjects tutoring including Maths, Science & English.',
            descriptionHi: 'गणित, विज्ञान और अंग्रेजी सहित सभी विषयों की ट्यूशन।',
            priceRange: '₹2000 - ₹5000 / month', icon: Icons.menu_book_rounded,
          ),
          const SubService(
            name: 'Spoken English', nameHi: 'स्पोकन इंग्लिश',
            description: 'Improve communication skills and grammar fluency.',
            descriptionHi: 'संचार कौशल और व्याकरण के प्रवाह में सुधार करें।',
            priceRange: '₹1500 - ₹3000 / month', icon: Icons.record_voice_over_rounded,
          ),
        ],
      )
    ];
  }
}
