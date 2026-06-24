import 'package:flutter/material.dart';

/// Maps a [Place.type]/category hint to a representative icon, for
/// quick visual scanning of mixed-type result lists. Shared by the
/// Search and Explore screens so result rows look consistent.
IconData iconForPlaceType(String type) {
  switch (type) {
    case 'restaurant':
    case 'cafe':
    case 'fast_food':
      return Icons.restaurant;
    case 'pharmacy':
      return Icons.local_pharmacy;
    case 'hospital':
    case 'clinic':
      return Icons.local_hospital;
    case 'bus_stop':
    case 'bus_station':
      return Icons.directions_bus;
    case 'hotel':
      return Icons.hotel;
    case 'parking':
      return Icons.local_parking;
    case 'supermarket':
      return Icons.shopping_cart;
    case 'bank':
      return Icons.account_balance;
    case 'school':
    case 'university':
      return Icons.school;
    case 'city':
    case 'town':
    case 'village':
    case 'suburb':
      return Icons.location_city;
    case 'house':
    case 'building':
      return Icons.home_outlined;
    default:
      return Icons.place_outlined;
  }
}
