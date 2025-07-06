import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class MerchantCategorizationService {
  static final MerchantCategorizationService _instance = MerchantCategorizationService._internal();
  factory MerchantCategorizationService() => _instance;
  MerchantCategorizationService._internal();

  // Comprehensive merchant database
  static const Map<String, MerchantInfo> _merchantDatabase = {
    // Grocery Stores
    'whole foods': MerchantInfo('Groceries', 'wholefoods.com', 'Whole Foods Market'),
    'trader joe': MerchantInfo('Groceries', 'traderjoes.com', 'Trader Joe\'s'),
    'safeway': MerchantInfo('Groceries', 'safeway.com', 'Safeway'),
    'kroger': MerchantInfo('Groceries', 'kroger.com', 'Kroger'),
    'walmart': MerchantInfo('Groceries', 'walmart.com', 'Walmart'),
    'target': MerchantInfo('Groceries', 'target.com', 'Target'),
    'costco': MerchantInfo('Groceries', 'costco.com', 'Costco'),
    'sams club': MerchantInfo('Groceries', 'samsclub.com', 'Sam\'s Club'),
    'publix': MerchantInfo('Groceries', 'publix.com', 'Publix'),
    'harris teeter': MerchantInfo('Groceries', 'harristeeter.com', 'Harris Teeter'),
    'food lion': MerchantInfo('Groceries', 'foodlion.com', 'Food Lion'),
    'giant': MerchantInfo('Groceries', 'giantfood.com', 'Giant'),
    'wegmans': MerchantInfo('Groceries', 'wegmans.com', 'Wegmans'),
    'aldi': MerchantInfo('Groceries', 'aldi.us', 'ALDI'),
    'fresh market': MerchantInfo('Groceries', 'thefreshmarket.com', 'The Fresh Market'),
    'sprouts': MerchantInfo('Groceries', 'sprouts.com', 'Sprouts'),
    'market basket': MerchantInfo('Groceries', 'demoulas.com', 'Market Basket'),
    'h-e-b': MerchantInfo('Groceries', 'heb.com', 'H-E-B'),
    'meijer': MerchantInfo('Groceries', 'meijer.com', 'Meijer'),
    'albertsons': MerchantInfo('Groceries', 'albertsons.com', 'Albertsons'),
    'stop shop': MerchantInfo('Groceries', 'stopandshop.com', 'Stop & Shop'),
    'king soopers': MerchantInfo('Groceries', 'kingsoopers.com', 'King Soopers'),

    // Fast Food & Quick Service
    'mcdonalds': MerchantInfo('Dining Out', 'mcdonalds.com', 'McDonald\'s'),
    'burger king': MerchantInfo('Dining Out', 'bk.com', 'Burger King'),
    'kfc': MerchantInfo('Dining Out', 'kfc.com', 'KFC'),
    'taco bell': MerchantInfo('Dining Out', 'tacobell.com', 'Taco Bell'),
    'subway': MerchantInfo('Dining Out', 'subway.com', 'Subway'),
    'chipotle': MerchantInfo('Dining Out', 'chipotle.com', 'Chipotle'),
    'panera': MerchantInfo('Dining Out', 'panerabread.com', 'Panera Bread'),
    'chick-fil-a': MerchantInfo('Dining Out', 'chick-fil-a.com', 'Chick-fil-A'),
    'in-n-out': MerchantInfo('Dining Out', 'in-n-out.com', 'In-N-Out'),
    'five guys': MerchantInfo('Dining Out', 'fiveguys.com', 'Five Guys'),
    'wendys': MerchantInfo('Dining Out', 'wendys.com', 'Wendy\'s'),
    'arby': MerchantInfo('Dining Out', 'arbys.com', 'Arby\'s'),
    'popeyes': MerchantInfo('Dining Out', 'popeyes.com', 'Popeyes'),
    'sonic': MerchantInfo('Dining Out', 'sonicdrivein.com', 'Sonic'),
    'dairy queen': MerchantInfo('Dining Out', 'dairyqueen.com', 'Dairy Queen'),
    'white castle': MerchantInfo('Dining Out', 'whitecastle.com', 'White Castle'),
    'jack in the box': MerchantInfo('Dining Out', 'jackinthebox.com', 'Jack in the Box'),

    // Coffee & Beverages
    'starbucks': MerchantInfo('Dining Out', 'starbucks.com', 'Starbucks'),
    'dunkin': MerchantInfo('Dining Out', 'dunkindonuts.com', 'Dunkin\''),
    'dutch bros': MerchantInfo('Dining Out', 'dutchbros.com', 'Dutch Bros'),
    'peets': MerchantInfo('Dining Out', 'peets.com', 'Peet\'s Coffee'),
    'caribou': MerchantInfo('Dining Out', 'cariboucoffee.com', 'Caribou Coffee'),

    // Pizza
    'pizza hut': MerchantInfo('Dining Out', 'pizzahut.com', 'Pizza Hut'),
    'dominos': MerchantInfo('Dining Out', 'dominos.com', 'Domino\'s'),
    'papa johns': MerchantInfo('Dining Out', 'papajohns.com', 'Papa John\'s'),
    'little caesars': MerchantInfo('Dining Out', 'littlecaesars.com', 'Little Caesars'),
    'papa murphy': MerchantInfo('Dining Out', 'papamurphys.com', 'Papa Murphy\'s'),

    // Casual Dining
    'olive garden': MerchantInfo('Dining Out', 'olivegarden.com', 'Olive Garden'),
    'applebees': MerchantInfo('Dining Out', 'applebees.com', 'Applebee\'s'),
    'chilis': MerchantInfo('Dining Out', 'chilis.com', 'Chili\'s'),
    'outback': MerchantInfo('Dining Out', 'outback.com', 'Outback Steakhouse'),
    'red lobster': MerchantInfo('Dining Out', 'redlobster.com', 'Red Lobster'),
    'buffalo wild wings': MerchantInfo('Dining Out', 'buffalowildwings.com', 'Buffalo Wild Wings'),
    'cracker barrel': MerchantInfo('Dining Out', 'crackerbarrel.com', 'Cracker Barrel'),
    'texas roadhouse': MerchantInfo('Dining Out', 'texasroadhouse.com', 'Texas Roadhouse'),
    'ihop': MerchantInfo('Dining Out', 'ihop.com', 'IHOP'),
    'dennys': MerchantInfo('Dining Out', 'dennys.com', 'Denny\'s'),

    // Gas Stations
    'shell': MerchantInfo('Transportation', 'shell.com', 'Shell'),
    'exxon': MerchantInfo('Transportation', 'exxon.com', 'Exxon'),
    'mobil': MerchantInfo('Transportation', 'mobil.com', 'Mobil'),
    'chevron': MerchantInfo('Transportation', 'chevron.com', 'Chevron'),
    'bp': MerchantInfo('Transportation', 'bp.com', 'BP'),
    'sunoco': MerchantInfo('Transportation', 'sunoco.com', 'Sunoco'),
    'citgo': MerchantInfo('Transportation', 'citgo.com', 'CITGO'),
    'valero': MerchantInfo('Transportation', 'valero.com', 'Valero'),
    'marathon': MerchantInfo('Transportation', 'marathonpetroleum.com', 'Marathon'),
    'speedway': MerchantInfo('Transportation', 'speedway.com', 'Speedway'),
    'wawa': MerchantInfo('Transportation', 'wawa.com', 'Wawa'),
    '7-eleven': MerchantInfo('Transportation', '7-eleven.com', '7-Eleven'),
    'circle k': MerchantInfo('Transportation', 'circlek.com', 'Circle K'),
    'casey': MerchantInfo('Transportation', 'caseys.com', 'Casey\'s'),

    // Transportation Services
    'uber': MerchantInfo('Transportation', 'uber.com', 'Uber'),
    'lyft': MerchantInfo('Transportation', 'lyft.com', 'Lyft'),
    'delta': MerchantInfo('Transportation', 'delta.com', 'Delta Air Lines'),
    'american airlines': MerchantInfo('Transportation', 'aa.com', 'American Airlines'),
    'united': MerchantInfo('Transportation', 'united.com', 'United Airlines'),
    'southwest': MerchantInfo('Transportation', 'southwest.com', 'Southwest Airlines'),
    'jetblue': MerchantInfo('Transportation', 'jetblue.com', 'JetBlue'),
    'spirit': MerchantInfo('Transportation', 'spirit.com', 'Spirit Airlines'),
    'hertz': MerchantInfo('Transportation', 'hertz.com', 'Hertz'),
    'enterprise': MerchantInfo('Transportation', 'enterprise.com', 'Enterprise'),
    'budget': MerchantInfo('Transportation', 'budget.com', 'Budget'),
    'avis': MerchantInfo('Transportation', 'avis.com', 'Avis'),

    // Retail Shopping
    'amazon': MerchantInfo('Shopping', 'amazon.com', 'Amazon'),
    'ebay': MerchantInfo('Shopping', 'ebay.com', 'eBay'),
    'best buy': MerchantInfo('Shopping', 'bestbuy.com', 'Best Buy'),
    'home depot': MerchantInfo('Shopping', 'homedepot.com', 'The Home Depot'),
    'lowes': MerchantInfo('Shopping', 'lowes.com', 'Lowe\'s'),
    'macys': MerchantInfo('Shopping', 'macys.com', 'Macy\'s'),
    'nordstrom': MerchantInfo('Shopping', 'nordstrom.com', 'Nordstrom'),
    'kohls': MerchantInfo('Shopping', 'kohls.com', 'Kohl\'s'),
    'jcpenney': MerchantInfo('Shopping', 'jcpenney.com', 'JCPenney'),
    'tj maxx': MerchantInfo('Shopping', 'tjmaxx.com', 'TJ Maxx'),
    'marshalls': MerchantInfo('Shopping', 'marshalls.com', 'Marshalls'),
    'ross': MerchantInfo('Shopping', 'rossstores.com', 'Ross'),
    'bed bath beyond': MerchantInfo('Shopping', 'bedbathandbeyond.com', 'Bed Bath & Beyond'),
    'bath body works': MerchantInfo('Shopping', 'bathandbodyworks.com', 'Bath & Body Works'),
    'victoria secret': MerchantInfo('Shopping', 'victoriassecret.com', 'Victoria\'s Secret'),
    'gap': MerchantInfo('Shopping', 'gap.com', 'Gap'),
    'old navy': MerchantInfo('Shopping', 'oldnavy.com', 'Old Navy'),
    'banana republic': MerchantInfo('Shopping', 'bananarepublic.com', 'Banana Republic'),
    'h&m': MerchantInfo('Shopping', 'hm.com', 'H&M'),
    'zara': MerchantInfo('Shopping', 'zara.com', 'Zara'),
    'uniqlo': MerchantInfo('Shopping', 'uniqlo.com', 'Uniqlo'),
    'forever 21': MerchantInfo('Shopping', 'forever21.com', 'Forever 21'),

    // Electronics & Technology
    'apple': MerchantInfo('Shopping', 'apple.com', 'Apple'),
    'microsoft': MerchantInfo('Shopping', 'microsoft.com', 'Microsoft'),
    'gamestop': MerchantInfo('Shopping', 'gamestop.com', 'GameStop'),
    'frys': MerchantInfo('Shopping', 'frys.com', 'Fry\'s Electronics'),
    'microcenter': MerchantInfo('Shopping', 'microcenter.com', 'Micro Center'),

    // Healthcare & Pharmacy
    'cvs': MerchantInfo('Healthcare', 'cvs.com', 'CVS Pharmacy'),
    'walgreens': MerchantInfo('Healthcare', 'walgreens.com', 'Walgreens'),
    'rite aid': MerchantInfo('Healthcare', 'riteaid.com', 'Rite Aid'),
    'kaiser': MerchantInfo('Healthcare', 'kp.org', 'Kaiser Permanente'),
    'blue cross': MerchantInfo('Healthcare', 'bcbs.com', 'Blue Cross Blue Shield'),
    'aetna': MerchantInfo('Healthcare', 'aetna.com', 'Aetna'),
    'cigna': MerchantInfo('Healthcare', 'cigna.com', 'Cigna'),
    'humana': MerchantInfo('Healthcare', 'humana.com', 'Humana'),
    'united health': MerchantInfo('Healthcare', 'uhc.com', 'UnitedHealthcare'),

    // Utilities & Services
    'verizon': MerchantInfo('Utilities', 'verizon.com', 'Verizon'),
    'at&t': MerchantInfo('Utilities', 'att.com', 'AT&T'),
    'att': MerchantInfo('Utilities', 'att.com', 'AT&T'),
    'comcast': MerchantInfo('Utilities', 'xfinity.com', 'Comcast Xfinity'),
    'xfinity': MerchantInfo('Utilities', 'xfinity.com', 'Comcast Xfinity'),
    'spectrum': MerchantInfo('Utilities', 'spectrum.com', 'Spectrum'),
    'tmobile': MerchantInfo('Utilities', 't-mobile.com', 'T-Mobile'),
    't-mobile': MerchantInfo('Utilities', 't-mobile.com', 'T-Mobile'),
    'sprint': MerchantInfo('Utilities', 'sprint.com', 'Sprint'),
    'cox': MerchantInfo('Utilities', 'cox.com', 'Cox Communications'),
    'time warner': MerchantInfo('Utilities', 'timewarnercable.com', 'Time Warner Cable'),
    'directv': MerchantInfo('Utilities', 'directv.com', 'DIRECTV'),
    'dish': MerchantInfo('Utilities', 'dish.com', 'DISH Network'),

    // Streaming & Subscriptions
    'netflix': MerchantInfo('Subscriptions', 'netflix.com', 'Netflix'),
    'spotify': MerchantInfo('Subscriptions', 'spotify.com', 'Spotify'),
    'amazon prime': MerchantInfo('Subscriptions', 'amazon.com', 'Amazon Prime'),
    'hulu': MerchantInfo('Subscriptions', 'hulu.com', 'Hulu'),
    'disney plus': MerchantInfo('Subscriptions', 'disneyplus.com', 'Disney+'),
    'disney+': MerchantInfo('Subscriptions', 'disneyplus.com', 'Disney+'),
    'apple music': MerchantInfo('Subscriptions', 'apple.com', 'Apple Music'),
    'youtube premium': MerchantInfo('Subscriptions', 'youtube.com', 'YouTube Premium'),
    'adobe': MerchantInfo('Subscriptions', 'adobe.com', 'Adobe'),
    'microsoft 365': MerchantInfo('Subscriptions', 'microsoft.com', 'Microsoft 365'),
    'office 365': MerchantInfo('Subscriptions', 'microsoft.com', 'Office 365'),
    'google one': MerchantInfo('Subscriptions', 'google.com', 'Google One'),
    'dropbox': MerchantInfo('Subscriptions', 'dropbox.com', 'Dropbox'),
    'icloud': MerchantInfo('Subscriptions', 'apple.com', 'iCloud'),
    'paramount': MerchantInfo('Subscriptions', 'paramountplus.com', 'Paramount+'),
    'hbo max': MerchantInfo('Subscriptions', 'hbomax.com', 'HBO Max'),
    'peacock': MerchantInfo('Subscriptions', 'peacocktv.com', 'Peacock'),
    'discovery': MerchantInfo('Subscriptions', 'discoveryplus.com', 'Discovery+'),

    // Fitness & Recreation
    'planet fitness': MerchantInfo('Entertainment', 'planetfitness.com', 'Planet Fitness'),
    'la fitness': MerchantInfo('Entertainment', 'lafitness.com', 'LA Fitness'),
    '24 hour fitness': MerchantInfo('Entertainment', '24hourfitness.com', '24 Hour Fitness'),
    'anytime fitness': MerchantInfo('Entertainment', 'anytimefitness.com', 'Anytime Fitness'),
    'equinox': MerchantInfo('Entertainment', 'equinox.com', 'Equinox'),
    'soulcycle': MerchantInfo('Entertainment', 'soul-cycle.com', 'SoulCycle'),
    'orange theory': MerchantInfo('Entertainment', 'orangetheory.com', 'Orange Theory'),
    'peloton': MerchantInfo('Entertainment', 'onepeloton.com', 'Peloton'),

    // Entertainment & Movies
    'amc': MerchantInfo('Entertainment', 'amctheatres.com', 'AMC Theatres'),
    'regal': MerchantInfo('Entertainment', 'regmovies.com', 'Regal Cinemas'),
    'cinemark': MerchantInfo('Entertainment', 'cinemark.com', 'Cinemark'),
    'dave busters': MerchantInfo('Entertainment', 'daveandbusters.com', 'Dave & Buster\'s'),
    'bowling': MerchantInfo('Entertainment', '', 'Bowling Alley'),
    'mini golf': MerchantInfo('Entertainment', '', 'Mini Golf'),

    // Financial Services
    'chase': MerchantInfo('Banking', 'chase.com', 'Chase Bank'),
    'bank of america': MerchantInfo('Banking', 'bankofamerica.com', 'Bank of America'),
    'wells fargo': MerchantInfo('Banking', 'wellsfargo.com', 'Wells Fargo'),
    'citibank': MerchantInfo('Banking', 'citibank.com', 'Citibank'),
    'us bank': MerchantInfo('Banking', 'usbank.com', 'U.S. Bank'),
    'capital one': MerchantInfo('Banking', 'capitalone.com', 'Capital One'),
    'discover': MerchantInfo('Banking', 'discover.com', 'Discover'),
    'american express': MerchantInfo('Banking', 'americanexpress.com', 'American Express'),
    'paypal': MerchantInfo('Banking', 'paypal.com', 'PayPal'),
    'venmo': MerchantInfo('Banking', 'venmo.com', 'Venmo'),
    'zelle': MerchantInfo('Banking', 'zellepay.com', 'Zelle'),
    'cashapp': MerchantInfo('Banking', 'cash.app', 'Cash App'),

    // Insurance
    'state farm': MerchantInfo('Insurance', 'statefarm.com', 'State Farm'),
    'geico': MerchantInfo('Insurance', 'geico.com', 'GEICO'),
    'progressive': MerchantInfo('Insurance', 'progressive.com', 'Progressive'),
    'allstate': MerchantInfo('Insurance', 'allstate.com', 'Allstate'),
    'farmers': MerchantInfo('Insurance', 'farmers.com', 'Farmers Insurance'),
    'liberty mutual': MerchantInfo('Insurance', 'libertymutual.com', 'Liberty Mutual'),
    'usaa': MerchantInfo('Insurance', 'usaa.com', 'USAA'),

    // Food Delivery
    'doordash': MerchantInfo('Dining Out', 'doordash.com', 'DoorDash'),
    'uber eats': MerchantInfo('Dining Out', 'ubereats.com', 'Uber Eats'),
    'grubhub': MerchantInfo('Dining Out', 'grubhub.com', 'Grubhub'),
    'postmates': MerchantInfo('Dining Out', 'postmates.com', 'Postmates'),
    'instacart': MerchantInfo('Groceries', 'instacart.com', 'Instacart'),
    'shipt': MerchantInfo('Groceries', 'shipt.com', 'Shipt'),

    // Hotels & Travel
    'marriott': MerchantInfo('Travel', 'marriott.com', 'Marriott'),
    'hilton': MerchantInfo('Travel', 'hilton.com', 'Hilton'),
    'hyatt': MerchantInfo('Travel', 'hyatt.com', 'Hyatt'),
    'holiday inn': MerchantInfo('Travel', 'holidayinn.com', 'Holiday Inn'),
    'best western': MerchantInfo('Travel', 'bestwestern.com', 'Best Western'),
    'airbnb': MerchantInfo('Travel', 'airbnb.com', 'Airbnb'),
    'booking.com': MerchantInfo('Travel', 'booking.com', 'Booking.com'),
    'expedia': MerchantInfo('Travel', 'expedia.com', 'Expedia'),
    'priceline': MerchantInfo('Travel', 'priceline.com', 'Priceline'),

    // Home Services
    'home advisor': MerchantInfo('Home Services', 'homeadvisor.com', 'HomeAdvisor'),
    'angie list': MerchantInfo('Home Services', 'angieslist.com', 'Angie\'s List'),
    'taskrabbit': MerchantInfo('Home Services', 'taskrabbit.com', 'TaskRabbit'),
    'thumbtack': MerchantInfo('Home Services', 'thumbtack.com', 'Thumbtack'),

    // Education
    'coursera': MerchantInfo('Education', 'coursera.org', 'Coursera'),
    'udemy': MerchantInfo('Education', 'udemy.com', 'Udemy'),
    'skillshare': MerchantInfo('Education', 'skillshare.com', 'Skillshare'),
    'masterclass': MerchantInfo('Education', 'masterclass.com', 'MasterClass'),
  };

  // Category keywords for fallback classification
  static const Map<String, List<String>> _categoryKeywords = {
    'Groceries': [
      'grocery', 'supermarket', 'market', 'food store', 'fresh', 'organic',
      'produce', 'butcher', 'bakery', 'deli', 'farmers market'
    ],
    'Dining Out': [
      'restaurant', 'cafe', 'coffee', 'bar', 'pub', 'grill', 'kitchen',
      'bistro', 'diner', 'food truck', 'takeout', 'delivery', 'pizza',
      'chinese', 'mexican', 'italian', 'thai', 'sushi', 'bbq'
    ],
    'Transportation': [
      'gas', 'fuel', 'parking', 'toll', 'taxi', 'rideshare', 'airline',
      'airport', 'car rental', 'metro', 'bus', 'train', 'subway',
      'automotive', 'repair', 'maintenance', 'oil change'
    ],
    'Shopping': [
      'retail', 'store', 'shop', 'mall', 'outlet', 'department',
      'clothing', 'apparel', 'shoes', 'electronics', 'furniture',
      'home goods', 'sporting goods', 'toys', 'books', 'jewelry'
    ],
    'Healthcare': [
      'hospital', 'clinic', 'doctor', 'dentist', 'pharmacy', 'medical',
      'health', 'urgent care', 'laboratory', 'imaging', 'therapy',
      'chiropractor', 'optometrist', 'veterinary', 'vet'
    ],
    'Utilities': [
      'electric', 'electricity', 'gas company', 'water', 'sewer',
      'internet', 'cable', 'phone', 'cellular', 'wireless',
      'telecom', 'utility', 'power', 'energy'
    ],
    'Entertainment': [
      'movie', 'theater', 'cinema', 'gym', 'fitness', 'sports',
      'recreation', 'amusement', 'theme park', 'concert', 'show',
      'museum', 'zoo', 'aquarium', 'bowling', 'golf', 'spa'
    ],
    'Insurance': [
      'insurance', 'auto insurance', 'health insurance', 'life insurance',
      'home insurance', 'renters insurance', 'dental insurance'
    ],
    'Rent': [
      'rent', 'rental', 'lease', 'apartment', 'property management',
      'real estate', 'mortgage', 'housing'
    ],
    'Subscriptions': [
      'subscription', 'monthly', 'annual', 'recurring', 'membership',
      'premium', 'pro', 'plus', 'streaming', 'software'
    ]
  };

  String categorizeTransaction(String merchantName, String description, List<dynamic>? plaidCategories) {
    final cleanMerchant = _cleanMerchantName(merchantName);
    final cleanDescription = _cleanMerchantName(description);
    
    // First, try exact merchant match
    final merchantInfo = _findMerchantMatch(cleanMerchant) ?? _findMerchantMatch(cleanDescription);
    if (merchantInfo != null) {
      return merchantInfo.category;
    }

    // Then try keyword-based classification
    final keywordCategory = _classifyByKeywords(cleanMerchant, cleanDescription);
    if (keywordCategory != null) {
      return keywordCategory;
    }

    // Finally, try Plaid categories as fallback
    if (plaidCategories != null && plaidCategories.isNotEmpty) {
      final plaidCategory = _mapPlaidCategories(plaidCategories);
      if (plaidCategory != null) {
        return plaidCategory;
      }
    }

    return 'Miscellaneous';
  }

  MerchantInfo? getMerchantInfo(String merchantName, String description) {
    final cleanMerchant = _cleanMerchantName(merchantName);
    final cleanDescription = _cleanMerchantName(description);
    
    return _findMerchantMatch(cleanMerchant) ?? _findMerchantMatch(cleanDescription);
  }

  String _cleanMerchantName(String name) {
    return name.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  MerchantInfo? _findMerchantMatch(String cleanName) {
    // Try exact match first
    if (_merchantDatabase.containsKey(cleanName)) {
      return _merchantDatabase[cleanName];
    }

    // Try partial matches
    for (final entry in _merchantDatabase.entries) {
      if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
        return entry.value;
      }
    }

    return null;
  }

  String? _classifyByKeywords(String merchantName, String description) {
    final text = '$merchantName $description';
    
    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  String? _mapPlaidCategories(List<dynamic> categories) {
    if (categories.isEmpty) return null;
    
    final primaryCategory = categories.first.toString().toLowerCase();
    final detailedCategory = categories.length > 1 ? categories.last.toString().toLowerCase() : '';
    
    // Food categories
    if (primaryCategory.contains('food') && primaryCategory.contains('drink')) {
      if (detailedCategory.contains('restaurant') || detailedCategory.contains('fast food') || 
          detailedCategory.contains('cafe') || detailedCategory.contains('bar')) {
        return 'Dining Out';
      }
      if (detailedCategory.contains('grocery') || detailedCategory.contains('supermarket')) {
        return 'Groceries';
      }
    }
    
    // Shopping
    if (primaryCategory.contains('shop') || primaryCategory.contains('retail')) {
      return 'Shopping';
    }
    
    // Transportation
    if (primaryCategory.contains('transport')) {
      return 'Transportation';
    }
    
    // Recreation/Entertainment
    if (primaryCategory.contains('recreation') || primaryCategory.contains('entertainment')) {
      return 'Entertainment';
    }
    
    // Healthcare
    if (primaryCategory.contains('healthcare') || primaryCategory.contains('medical')) {
      return 'Healthcare';
    }
    
    // Service (utilities, etc)
    if (primaryCategory.contains('service')) {
      if (detailedCategory.contains('utilities') || detailedCategory.contains('internet') ||
          detailedCategory.contains('phone') || detailedCategory.contains('cable')) {
        return 'Utilities';
      }
    }
    
    // Payment (rent, loans, etc)
    if (primaryCategory.contains('payment')) {
      if (detailedCategory.contains('rent') || detailedCategory.contains('mortgage')) {
        return 'Rent';
      }
      if (detailedCategory.contains('insurance')) {
        return 'Insurance';
      }
    }
    
    return null;
  }

  // Get company logo URL
  Future<String?> getCompanyLogoUrl(String merchantName, String? domain) async {
    try {
      // Try Clearbit Logo API first
      if (domain != null && domain.isNotEmpty) {
        final clearbitUrl = 'https://logo.clearbit.com/$domain';
        final response = await http.head(Uri.parse(clearbitUrl));
        if (response.statusCode == 200) {
          return clearbitUrl;
        }
      }

      // Try favicon as fallback
      if (domain != null && domain.isNotEmpty) {
        final faviconUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
        return faviconUrl;
      }

      return null;
    } catch (e) {
      print('Error fetching logo for $merchantName: $e');
      return null;
    }
  }

  // Get enhanced merchant information including logo
  Future<EnhancedMerchantInfo> getEnhancedMerchantInfo(String merchantName, String description) async {
    final merchantInfo = getMerchantInfo(merchantName, description);
    final category = categorizeTransaction(merchantName, description, null);
    
    String? logoUrl;
    String displayName = merchantName;
    String? website;

    if (merchantInfo != null) {
      displayName = merchantInfo.displayName;
      website = merchantInfo.domain;
      logoUrl = await getCompanyLogoUrl(displayName, merchantInfo.domain);
    } else {
      // Try to get logo for unknown merchants
      final cleanName = _cleanMerchantName(merchantName);
      final guessedDomain = '${cleanName.replaceAll(' ', '')}.com';
      logoUrl = await getCompanyLogoUrl(merchantName, guessedDomain);
    }

    return EnhancedMerchantInfo(
      category: category,
      displayName: displayName,
      logoUrl: logoUrl,
      website: website,
      originalName: merchantName,
    );
  }
}

class MerchantInfo {
  final String category;
  final String domain;
  final String displayName;

  const MerchantInfo(this.category, this.domain, this.displayName);
}

class EnhancedMerchantInfo {
  final String category;
  final String displayName;
  final String? logoUrl;
  final String? website;
  final String originalName;

  const EnhancedMerchantInfo({
    required this.category,
    required this.displayName,
    this.logoUrl,
    this.website,
    required this.originalName,
  });
}