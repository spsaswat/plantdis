const Map<String, String> fallbackDiseaseSuggestions = {
  'Corn___Cercospora_leaf_spot_Gray_leaf_spot':
      'Remove heavily infected leaves and crop debris, improve spacing and airflow, and avoid overhead irrigation late in the day. Rotate away from corn for at least one season and monitor nearby plants closely. If disease pressure is high, use a labeled fungicide early before lesions spread widely.',
  'Corn___Common_rust':
      'Remove badly infected leaves when practical, reduce plant stress with balanced water and nutrition, and keep the field free of volunteer corn that can carry disease. Scout often because rust spreads quickly in cool, humid weather. Use a labeled fungicide if infection is increasing and the crop is still in a responsive growth stage.',
  'Corn___healthy':
      'Your corn appears healthy. Keep monitoring weekly, water consistently at the base, maintain balanced fertilization, and remove weeds and crop debris to reduce future disease pressure.',
  'Corn___Northern_Leaf_Blight':
      'Remove infected residue after harvest, rotate with non-host crops, and avoid dense planting that traps moisture. Watch lower leaves for elongated lesions and act early if spread increases. A labeled fungicide can help protect new growth when weather is humid and disease pressure is moderate to high.',
  'Pepper_bacterial_spot':
      'Remove infected leaves and severely affected plants, avoid handling wet foliage, and disinfect tools after contact. Water at the soil level instead of overhead to reduce splash spread. Use clean seed or transplants in future plantings and consider a labeled copper-based product where locally appropriate.',
  'Pepper_healthy':
      'Your pepper appears healthy. Continue regular scouting, water at the base, avoid overcrowding, and keep leaves dry as much as possible to prevent disease buildup.',
  'Grape___Black_rot':
      'Prune out infected shoots and mummified fruit, improve canopy airflow, and clean up fallen debris because the fungus overwinters there. Avoid prolonged leaf wetness where possible and protect new growth during wet periods with a labeled fungicide program suited for grapes.',
  'Grape___Esca_(Black_Measles)':
      'Prune out symptomatic wood only in dry conditions and disinfect pruning tools between cuts. Reduce vine stress with proper irrigation and nutrition, and mark severely affected vines for close follow-up because trunk diseases can persist internally. Remove dead wood and avoid unnecessary wounds that let pathogens enter.',
  'Grape___Esca(Black_Measles)':
      'Prune out symptomatic wood only in dry conditions and disinfect pruning tools between cuts. Reduce vine stress with proper irrigation and nutrition, and mark severely affected vines for close follow-up because trunk diseases can persist internally. Remove dead wood and avoid unnecessary wounds that let pathogens enter.',
  'Grape___healthy':
      'Your grape leaf appears healthy. Maintain pruning for airflow, monitor regularly for spots or discoloration, and keep the canopy dry and open to lower disease risk.',
  'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)':
      'Remove infected leaves and vineyard debris, improve sunlight penetration and airflow through pruning, and avoid overhead irrigation. Begin control early in warm, humid periods because leaf blight can spread fast. Use an approved fungicide for grapes if symptoms continue expanding.',
  'Apple___Apple_scab':
      'Remove fallen leaves and infected fruit, prune for better airflow, and avoid overhead watering. Apple scab spreads strongly in cool, wet weather, so protect new leaves early in the season. If pressure is persistent, apply a labeled fungicide on a timely schedule and sanitize orchard debris well.',
  'Apple___Black_rot':
      'Remove mummified fruit, cankers, and infected twigs promptly, then destroy the debris away from the tree. Prune to open the canopy and disinfect tools after cutting diseased wood. Protect fruit and new shoots during wet weather with a labeled fungicide if black rot has been recurring.',
  'Apple___Cedar_apple_rust':
      'Remove nearby alternate hosts such as infected junipers when possible, prune to improve airflow, and monitor young leaves and fruit closely in spring. Disease spreads in wet weather, so timely preventive fungicide sprays may be needed in areas with recurring rust pressure.',
  'Apple___healthy':
      'Your apple leaf appears healthy. Keep the canopy open with pruning, clear fallen debris, and continue routine monitoring so any early disease symptoms can be caught quickly.',
  'Potato___Early_blight':
      'Remove badly infected leaves, avoid wetting foliage unnecessarily, and keep good spacing for airflow. Mulch can help reduce soil splash, and rotation away from potatoes and tomatoes lowers carryover. If lesions continue spreading, use a labeled fungicide early before heavy defoliation develops.',
  'Potato___healthy':
      'Your potato leaf appears healthy. Keep watering consistent, avoid overhead irrigation late in the day, and continue scouting so any blight symptoms are caught early.',
  'Potato___Late_blight':
      'Act quickly because late blight spreads aggressively in cool, wet conditions. Remove and isolate infected foliage, avoid overhead irrigation, and do not compost heavily diseased material. Inspect nearby potato and tomato plants immediately and use an appropriate labeled fungicide as soon as possible.',
  'Tomato___Bacterial_spot':
      'Remove infected leaves, avoid touching plants when wet, and disinfect tools and hands after handling affected plants. Water at the base to reduce splash spread and keep plants well spaced for airflow. Copper-based products may help suppress spread where locally recommended.',
  'Tomato___Early_blight':
      'Prune lower infected leaves, mulch to reduce soil splash, and water at the base instead of over the foliage. Rotate crops and remove old plant debris because the fungus survives between seasons. Use a labeled fungicide if spotting continues to move upward through the plant.',
  'Tomato___healthy':
      'Your tomato leaf appears healthy. Keep foliage dry when possible, maintain spacing and pruning for airflow, and monitor often for early spots, mold, or curling.',
  'Tomato___Late_blight':
      'This can spread very fast in cool, humid weather. Remove infected tissue immediately, isolate affected plants, and avoid overhead watering. Check nearby tomatoes and potatoes right away and use a labeled late blight fungicide promptly because delays can lead to rapid crop loss.',
  'Tomato___Leaf_Mold':
      'Improve ventilation, reduce humidity around the plant, and avoid overhead irrigation, especially in enclosed spaces. Remove infected leaves promptly and keep foliage from staying wet for long periods. A labeled fungicide may help if leaf mold continues to spread.',
  'Tomato___Septoria_leaf_spot':
      'Remove lower infected leaves early, mulch to block soil splash, and water only at the base. Clean up fallen debris and rotate crops because the pathogen persists on residue. If spread continues, apply a labeled fungicide before defoliation becomes severe.',
  'Tomato___Spider_mites_Two_spotted_spider_mite':
      'Rinse leaf undersides with water where practical, remove badly infested leaves, and reduce dusty, hot stress conditions that favor mites. Inspect the underside of nearby leaves for fine webbing and stippling. Insecticidal soap, horticultural oil, or a labeled miticide may help when infestations build.',
  'Tomato___Target_Spot':
      'Remove infected leaves and crop debris, improve spacing and airflow, and avoid overhead watering. Monitor during warm, humid weather because target spot can move quickly through dense foliage. Use a labeled fungicide if the disease is progressing across multiple leaves or plants.',
  'Tomato___Tomato_mosaic_virus':
      'There is no curative treatment, so focus on containment. Remove severely affected plants, disinfect hands and tools, and avoid handling tobacco products before touching tomatoes. Control weeds and use clean planting material because the virus spreads mechanically.',
  'Tomato___Tomato_Yellow_Leaf_Curl_Virus':
      'Remove heavily affected plants early, control whiteflies aggressively, and use reflective mulch or netting where possible to reduce vector pressure. Keep weeds down because they can host both the virus and whiteflies. There is no cure, so preventing spread to healthy plants is the priority.',
};

String? fallbackSuggestionForDisease(String diseaseLabel) {
  if (diseaseLabel.isEmpty) return null;
  return fallbackDiseaseSuggestions[diseaseLabel];
}
