## 0.1.0

* Initial release.
* `getCapabilities()` lists the delta data types this watch can measure.
* `measure(type)` streams `MeasureSample` and `MeasureAvailabilityChanged`
  events for a data type; listeners share one native registration.
* Typed errors: `HealthServicesUnavailableException`,
  `UnsupportedDataTypeException`, `PermissionDeniedException`,
  `MeasureRegistrationFailedException`.
* Safe for multi-engine apps: detaching one engine only unregisters the
  callbacks that engine registered.
* All numeric delta data types of health-services-client 1.1.0 are supported;
  `LOCATION` is not part of this release.
