class AIService {
  static Future<String> getTravelAdvice(String userPrompt) async {
    final query = userPrompt.toLowerCase().trim();

    // Simulate intelligent travel assistant responses tailored for Travelink users
    await Future.delayed(const Duration(milliseconds: 800));

    if (query.contains('goa') || query.contains('beach')) {
      return "🌴 **3-Day Goa Beach Itinerary**:\n\n"
          "• **Day 1**: Arrive at North Goa. Relax at Baga & Calangute Beach, enjoy beach shack dinners.\n"
          "• **Day 2**: Historic Old Goa Churches (Basilica of Bom Jesus) & Spice Plantation tour.\n"
          "• **Day 3**: South Goa peaceful beaches (Palolem, Agonda) & Sunset Cruise on Mandovi River.\n\n"
          "💡 **Top Tip**: Best months to visit are November to February for pleasant weather!";
    } else if (query.contains('kerala') || query.contains('backwater')) {
      return "🚣 **Kerala Backwaters & Nature Guide**:\n\n"
          "• **Alleppey**: Book an overnight Houseboat stay on the backwaters for stunning views.\n"
          "• **Munnar**: Visit lush tea gardens, Mattupetty Dam, and Eravikulam National Park.\n"
          "• **Kochi**: Explore Fort Kochi Chinese Fishing Nets & Jew Town.\n\n"
          "💡 **Budget Tip**: Homestays in Munnar offer authentic local food at fraction of resort costs!";
    } else if (query.contains('budget') || query.contains('save money') || query.contains('cheap')) {
      return "💰 **Smart Travel Budgeting Tips**:\n\n"
          "1. **Book Flights 6-8 Weeks Ahead**: Tuesdays & Wednesdays usually offer cheaper rates.\n"
          "2. **Stay in Verified Homestays**: Often 40% cheaper than hotels with free homecooked breakfasts.\n"
          "3. **Use Public Transport**: Local trains & buses give you an authentic experience while saving money.\n"
          "4. **Eat Local**: Check out Travelink's *Places* tab for highly rated street food and local cafes!";
    } else if (query.contains('pack') || query.contains('packing') || query.contains('bring')) {
      return "🎒 **Essential Travel Packing Checklist**:\n\n"
          "✓ **Documents**: ID, copies of tickets, hotel bookings, emergency contacts.\n"
          "✓ **Electronics**: Universal adapter, power bank, portable chargers.\n"
          "✓ **First Aid**: Basic medications, band-aids, hand sanitizer, sunblock.\n"
          "✓ **Wearables**: Comfortable walking shoes, weather-appropriate clothing, sunglasses.";
    } else if (query.contains('paris') || query.contains('france') || query.contains('europe')) {
      return "🗼 **Paris & European Travel Highlights**:\n\n"
          "• **Must Visit**: Eiffel Tower at dusk, Louvre Museum (book tickets online to skip line), Montmartre.\n"
          "• **Best Season**: May to June or September to October (fewer crowds, mild weather).\n"
          "• **Local Phrase**: Always greet shopkeepers with *'Bonjour!'* for friendly service.";
    } else {
      return "🤖 **Travelink AI Assistant Advice**:\n\n"
          "Great destination choice for your trip to **${userPrompt.trim()}**!\n\n"
          "• **Recommended Duration**: 3-5 days for a complete experience.\n"
          "• **Best Activities**: Explore top-rated local cafes on the *Places* tab, take a guided walking tour, and visit cultural landmarks.\n"
          "• **Connecting with Travelers**: Check out trip posts in the *Explore* feed and tap *'Ask Traveler'* to chat 1-on-1 with someone who visited recently!";
    }
  }
}
