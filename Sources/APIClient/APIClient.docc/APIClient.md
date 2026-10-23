# ``APIClient``

Bare-bones async JSON client for path- or ``Endpoint``-based `response` calls.

## Overview

Pass a path string for GET, or for POST when the call includes a request body.
Pass an ``Endpoint`` to name another method. Query items accept a dictionary
literal or any ``QueryItemsConvertible`` value.

## Getting started

The interactive tutorial walks through every `response` body shape against
OpenWeather’s Stations API, in call order: create station, list stations, post
measurements, get measurements, then delete the station.

- <doc:Calling-the-Stations-API>
