// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../aggregation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AggregateNodeRef {

 int get sourceId; String get provider; String get fingerprint; String get name;
/// Create a copy of AggregateNodeRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AggregateNodeRefCopyWith<AggregateNodeRef> get copyWith => _$AggregateNodeRefCopyWithImpl<AggregateNodeRef>(this as AggregateNodeRef, _$identity);

  /// Serializes this AggregateNodeRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AggregateNodeRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AggregateNodeRef&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.fingerprint, _this.fingerprint) || other.fingerprint == _this.fingerprint)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AggregateNodeRef;
  return Object.hash(runtimeType,_this.sourceId,_this.provider,_this.fingerprint,_this.name);
}

@override
String toString() {
  final _this = this as AggregateNodeRef;
  return 'AggregateNodeRef(sourceId: ${_this.sourceId}, provider: ${_this.provider}, fingerprint: ${_this.fingerprint}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $AggregateNodeRefCopyWith<$Res>  {
  factory $AggregateNodeRefCopyWith(AggregateNodeRef value, $Res Function(AggregateNodeRef) _then) = _$AggregateNodeRefCopyWithImpl;
@useResult
$Res call({
 int sourceId, String provider, String fingerprint, String name
});




}
/// @nodoc
class _$AggregateNodeRefCopyWithImpl<$Res>
    implements $AggregateNodeRefCopyWith<$Res> {
  _$AggregateNodeRefCopyWithImpl(this._self, this._then);

  final AggregateNodeRef _self;
  final $Res Function(AggregateNodeRef) _then;

/// Create a copy of AggregateNodeRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? provider = null,Object? fingerprint = null,Object? name = null,}) {
  return _then(AggregateNodeRef(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AggregateNodeRef].
extension AggregateNodeRefPatterns on AggregateNodeRef {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AggregateNodeRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AggregateNodeRef() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AggregateNodeRef value)  $default,){
final _that = this;
switch (_that) {
case _AggregateNodeRef():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AggregateNodeRef value)?  $default,){
final _that = this;
switch (_that) {
case _AggregateNodeRef() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sourceId,  String provider,  String fingerprint,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AggregateNodeRef() when $default != null:
return $default(_that.sourceId,_that.provider,_that.fingerprint,_that.name);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sourceId,  String provider,  String fingerprint,  String name)  $default,) {final _that = this;
switch (_that) {
case _AggregateNodeRef():
return $default(_that.sourceId,_that.provider,_that.fingerprint,_that.name);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sourceId,  String provider,  String fingerprint,  String name)?  $default,) {final _that = this;
switch (_that) {
case _AggregateNodeRef() when $default != null:
return $default(_that.sourceId,_that.provider,_that.fingerprint,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AggregateNodeRef implements AggregateNodeRef {
  const _AggregateNodeRef({required this.sourceId, this.provider = '', required this.fingerprint, required this.name});
  factory _AggregateNodeRef.fromJson(Map<String, dynamic> json) => _$AggregateNodeRefFromJson(json);

@override final  int sourceId;
@override@JsonKey() final  String provider;
@override final  String fingerprint;
@override final  String name;

/// Create a copy of AggregateNodeRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AggregateNodeRefCopyWith<_AggregateNodeRef> get copyWith => __$AggregateNodeRefCopyWithImpl<_AggregateNodeRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AggregateNodeRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AggregateNodeRef&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.fingerprint, fingerprint) || other.fingerprint == fingerprint)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sourceId,provider,fingerprint,name);
}

@override
String toString() {
    return 'AggregateNodeRef(sourceId: $sourceId, provider: $provider, fingerprint: $fingerprint, name: $name)';
}


}

/// @nodoc
abstract mixin class _$AggregateNodeRefCopyWith<$Res> implements $AggregateNodeRefCopyWith<$Res> {
  factory _$AggregateNodeRefCopyWith(_AggregateNodeRef value, $Res Function(_AggregateNodeRef) _then) = __$AggregateNodeRefCopyWithImpl;
@override @useResult
$Res call({
 int sourceId, String provider, String fingerprint, String name
});




}
/// @nodoc
class __$AggregateNodeRefCopyWithImpl<$Res>
    implements _$AggregateNodeRefCopyWith<$Res> {
  __$AggregateNodeRefCopyWithImpl(this._self, this._then);

  final _AggregateNodeRef _self;
  final $Res Function(_AggregateNodeRef) _then;

/// Create a copy of AggregateNodeRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? provider = null,Object? fingerprint = null,Object? name = null,}) {
  return _then(_AggregateNodeRef(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as int,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ProxyChain {

 String get id; String get name; AggregateNodeRef get entry; AggregateNodeRef get exit;
/// Create a copy of ProxyChain
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProxyChainCopyWith<ProxyChain> get copyWith => _$ProxyChainCopyWithImpl<ProxyChain>(this as ProxyChain, _$identity);

  /// Serializes this ProxyChain to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProxyChain;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProxyChain&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.entry, _this.entry) || other.entry == _this.entry)&&(identical(other.exit, _this.exit) || other.exit == _this.exit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProxyChain;
  return Object.hash(runtimeType,_this.id,_this.name,_this.entry,_this.exit);
}

@override
String toString() {
  final _this = this as ProxyChain;
  return 'ProxyChain(id: ${_this.id}, name: ${_this.name}, entry: ${_this.entry}, exit: ${_this.exit})';
}


}

/// @nodoc
abstract mixin class $ProxyChainCopyWith<$Res>  {
  factory $ProxyChainCopyWith(ProxyChain value, $Res Function(ProxyChain) _then) = _$ProxyChainCopyWithImpl;
@useResult
$Res call({
 String id, String name, AggregateNodeRef entry, AggregateNodeRef exit
});


$AggregateNodeRefCopyWith<$Res> get entry;$AggregateNodeRefCopyWith<$Res> get exit;

}
/// @nodoc
class _$ProxyChainCopyWithImpl<$Res>
    implements $ProxyChainCopyWith<$Res> {
  _$ProxyChainCopyWithImpl(this._self, this._then);

  final ProxyChain _self;
  final $Res Function(ProxyChain) _then;

/// Create a copy of ProxyChain
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? entry = null,Object? exit = null,}) {
  return _then(ProxyChain(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as AggregateNodeRef,exit: null == exit ? _self.exit : exit // ignore: cast_nullable_to_non_nullable
as AggregateNodeRef,
  ));
}
/// Create a copy of ProxyChain
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AggregateNodeRefCopyWith<$Res> get entry {
  
  return $AggregateNodeRefCopyWith<$Res>(_self.entry, (value) {
    return _then(_self.copyWith(entry: value));
  });
}/// Create a copy of ProxyChain
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AggregateNodeRefCopyWith<$Res> get exit {
  
  return $AggregateNodeRefCopyWith<$Res>(_self.exit, (value) {
    return _then(_self.copyWith(exit: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProxyChain].
extension ProxyChainPatterns on ProxyChain {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProxyChain value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProxyChain() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProxyChain value)  $default,){
final _that = this;
switch (_that) {
case _ProxyChain():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProxyChain value)?  $default,){
final _that = this;
switch (_that) {
case _ProxyChain() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  AggregateNodeRef entry,  AggregateNodeRef exit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProxyChain() when $default != null:
return $default(_that.id,_that.name,_that.entry,_that.exit);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  AggregateNodeRef entry,  AggregateNodeRef exit)  $default,) {final _that = this;
switch (_that) {
case _ProxyChain():
return $default(_that.id,_that.name,_that.entry,_that.exit);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  AggregateNodeRef entry,  AggregateNodeRef exit)?  $default,) {final _that = this;
switch (_that) {
case _ProxyChain() when $default != null:
return $default(_that.id,_that.name,_that.entry,_that.exit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProxyChain implements ProxyChain {
  const _ProxyChain({required this.id, required this.name, required this.entry, required this.exit});
  factory _ProxyChain.fromJson(Map<String, dynamic> json) => _$ProxyChainFromJson(json);

@override final  String id;
@override final  String name;
@override final  AggregateNodeRef entry;
@override final  AggregateNodeRef exit;

/// Create a copy of ProxyChain
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProxyChainCopyWith<_ProxyChain> get copyWith => __$ProxyChainCopyWithImpl<_ProxyChain>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProxyChainToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProxyChain&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.exit, exit) || other.exit == exit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,entry,exit);
}

@override
String toString() {
    return 'ProxyChain(id: $id, name: $name, entry: $entry, exit: $exit)';
}


}

/// @nodoc
abstract mixin class _$ProxyChainCopyWith<$Res> implements $ProxyChainCopyWith<$Res> {
  factory _$ProxyChainCopyWith(_ProxyChain value, $Res Function(_ProxyChain) _then) = __$ProxyChainCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, AggregateNodeRef entry, AggregateNodeRef exit
});


@override $AggregateNodeRefCopyWith<$Res> get entry;@override $AggregateNodeRefCopyWith<$Res> get exit;

}
/// @nodoc
class __$ProxyChainCopyWithImpl<$Res>
    implements _$ProxyChainCopyWith<$Res> {
  __$ProxyChainCopyWithImpl(this._self, this._then);

  final _ProxyChain _self;
  final $Res Function(_ProxyChain) _then;

/// Create a copy of ProxyChain
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? entry = null,Object? exit = null,}) {
  return _then(_ProxyChain(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as AggregateNodeRef,exit: null == exit ? _self.exit : exit // ignore: cast_nullable_to_non_nullable
as AggregateNodeRef,
  ));
}

/// Create a copy of ProxyChain
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AggregateNodeRefCopyWith<$Res> get entry {
  
  return $AggregateNodeRefCopyWith<$Res>(_self.entry, (value) {
    return _then(_self.copyWith(entry: value));
  });
}/// Create a copy of ProxyChain
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AggregateNodeRefCopyWith<$Res> get exit {
  
  return $AggregateNodeRefCopyWith<$Res>(_self.exit, (value) {
    return _then(_self.copyWith(exit: value));
  });
}
}


/// @nodoc
mixin _$AggregateConfig {

 int? get baseProfileId; Set<int> get sourceIds; String get targetGroup; String get groupName; List<ProxyChain> get chains;
/// Create a copy of AggregateConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AggregateConfigCopyWith<AggregateConfig> get copyWith => _$AggregateConfigCopyWithImpl<AggregateConfig>(this as AggregateConfig, _$identity);

  /// Serializes this AggregateConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AggregateConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AggregateConfig&&(identical(other.baseProfileId, _this.baseProfileId) || other.baseProfileId == _this.baseProfileId)&&const DeepCollectionEquality().equals(other.sourceIds, _this.sourceIds)&&(identical(other.targetGroup, _this.targetGroup) || other.targetGroup == _this.targetGroup)&&(identical(other.groupName, _this.groupName) || other.groupName == _this.groupName)&&const DeepCollectionEquality().equals(other.chains, _this.chains));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AggregateConfig;
  return Object.hash(runtimeType,_this.baseProfileId,const DeepCollectionEquality().hash(_this.sourceIds),_this.targetGroup,_this.groupName,const DeepCollectionEquality().hash(_this.chains));
}

@override
String toString() {
  final _this = this as AggregateConfig;
  return 'AggregateConfig(baseProfileId: ${_this.baseProfileId}, sourceIds: ${_this.sourceIds}, targetGroup: ${_this.targetGroup}, groupName: ${_this.groupName}, chains: ${_this.chains})';
}


}

/// @nodoc
abstract mixin class $AggregateConfigCopyWith<$Res>  {
  factory $AggregateConfigCopyWith(AggregateConfig value, $Res Function(AggregateConfig) _then) = _$AggregateConfigCopyWithImpl;
@useResult
$Res call({
 int? baseProfileId, Set<int> sourceIds, String targetGroup, String groupName, List<ProxyChain> chains
});




}
/// @nodoc
class _$AggregateConfigCopyWithImpl<$Res>
    implements $AggregateConfigCopyWith<$Res> {
  _$AggregateConfigCopyWithImpl(this._self, this._then);

  final AggregateConfig _self;
  final $Res Function(AggregateConfig) _then;

/// Create a copy of AggregateConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? baseProfileId = freezed,Object? sourceIds = null,Object? targetGroup = null,Object? groupName = null,Object? chains = null,}) {
  return _then(AggregateConfig(
baseProfileId: freezed == baseProfileId ? _self.baseProfileId : baseProfileId // ignore: cast_nullable_to_non_nullable
as int?,sourceIds: null == sourceIds ? _self.sourceIds : sourceIds // ignore: cast_nullable_to_non_nullable
as Set<int>,targetGroup: null == targetGroup ? _self.targetGroup : targetGroup // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,chains: null == chains ? _self.chains : chains // ignore: cast_nullable_to_non_nullable
as List<ProxyChain>,
  ));
}

}


/// Adds pattern-matching-related methods to [AggregateConfig].
extension AggregateConfigPatterns on AggregateConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AggregateConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AggregateConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AggregateConfig value)  $default,){
final _that = this;
switch (_that) {
case _AggregateConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AggregateConfig value)?  $default,){
final _that = this;
switch (_that) {
case _AggregateConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? baseProfileId,  Set<int> sourceIds,  String targetGroup,  String groupName,  List<ProxyChain> chains)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AggregateConfig() when $default != null:
return $default(_that.baseProfileId,_that.sourceIds,_that.targetGroup,_that.groupName,_that.chains);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? baseProfileId,  Set<int> sourceIds,  String targetGroup,  String groupName,  List<ProxyChain> chains)  $default,) {final _that = this;
switch (_that) {
case _AggregateConfig():
return $default(_that.baseProfileId,_that.sourceIds,_that.targetGroup,_that.groupName,_that.chains);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? baseProfileId,  Set<int> sourceIds,  String targetGroup,  String groupName,  List<ProxyChain> chains)?  $default,) {final _that = this;
switch (_that) {
case _AggregateConfig() when $default != null:
return $default(_that.baseProfileId,_that.sourceIds,_that.targetGroup,_that.groupName,_that.chains);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AggregateConfig implements AggregateConfig {
  const _AggregateConfig({this.baseProfileId,  Set<int> sourceIds = const {}, this.targetGroup = '', this.groupName = 'Aggregate',  List<ProxyChain> chains = const []}): _sourceIds = sourceIds,_chains = chains;
  factory _AggregateConfig.fromJson(Map<String, dynamic> json) => _$AggregateConfigFromJson(json);

@override final  int? baseProfileId;
 final  Set<int> _sourceIds;
@override@JsonKey() Set<int> get sourceIds {
  if (_sourceIds is EqualUnmodifiableSetView) return _sourceIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_sourceIds);
}

@override@JsonKey() final  String targetGroup;
@override@JsonKey() final  String groupName;
 final  List<ProxyChain> _chains;
@override@JsonKey() List<ProxyChain> get chains {
  if (_chains is EqualUnmodifiableListView) return _chains;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chains);
}


/// Create a copy of AggregateConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AggregateConfigCopyWith<_AggregateConfig> get copyWith => __$AggregateConfigCopyWithImpl<_AggregateConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AggregateConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AggregateConfig&&(identical(other.baseProfileId, baseProfileId) || other.baseProfileId == baseProfileId)&&const DeepCollectionEquality().equals(other.sourceIds, _sourceIds)&&(identical(other.targetGroup, targetGroup) || other.targetGroup == targetGroup)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&const DeepCollectionEquality().equals(other.chains, _chains));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,baseProfileId,const DeepCollectionEquality().hash(_sourceIds),targetGroup,groupName,const DeepCollectionEquality().hash(_chains));
}

@override
String toString() {
    return 'AggregateConfig(baseProfileId: $baseProfileId, sourceIds: $sourceIds, targetGroup: $targetGroup, groupName: $groupName, chains: $chains)';
}


}

/// @nodoc
abstract mixin class _$AggregateConfigCopyWith<$Res> implements $AggregateConfigCopyWith<$Res> {
  factory _$AggregateConfigCopyWith(_AggregateConfig value, $Res Function(_AggregateConfig) _then) = __$AggregateConfigCopyWithImpl;
@override @useResult
$Res call({
 int? baseProfileId, Set<int> sourceIds, String targetGroup, String groupName, List<ProxyChain> chains
});




}
/// @nodoc
class __$AggregateConfigCopyWithImpl<$Res>
    implements _$AggregateConfigCopyWith<$Res> {
  __$AggregateConfigCopyWithImpl(this._self, this._then);

  final _AggregateConfig _self;
  final $Res Function(_AggregateConfig) _then;

/// Create a copy of AggregateConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? baseProfileId = freezed,Object? sourceIds = null,Object? targetGroup = null,Object? groupName = null,Object? chains = null,}) {
  return _then(_AggregateConfig(
baseProfileId: freezed == baseProfileId ? _self.baseProfileId : baseProfileId // ignore: cast_nullable_to_non_nullable
as int?,sourceIds: null == sourceIds ? _self._sourceIds : sourceIds // ignore: cast_nullable_to_non_nullable
as Set<int>,targetGroup: null == targetGroup ? _self.targetGroup : targetGroup // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,chains: null == chains ? _self._chains : chains // ignore: cast_nullable_to_non_nullable
as List<ProxyChain>,
  ));
}


}


/// @nodoc
mixin _$AggregateWorkspace {

 int? get profileId; AggregateConfig get draft; Set<String> get favorites;
/// Create a copy of AggregateWorkspace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AggregateWorkspaceCopyWith<AggregateWorkspace> get copyWith => _$AggregateWorkspaceCopyWithImpl<AggregateWorkspace>(this as AggregateWorkspace, _$identity);

  /// Serializes this AggregateWorkspace to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AggregateWorkspace;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AggregateWorkspace&&(identical(other.profileId, _this.profileId) || other.profileId == _this.profileId)&&(identical(other.draft, _this.draft) || other.draft == _this.draft)&&const DeepCollectionEquality().equals(other.favorites, _this.favorites));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AggregateWorkspace;
  return Object.hash(runtimeType,_this.profileId,_this.draft,const DeepCollectionEquality().hash(_this.favorites));
}

@override
String toString() {
  final _this = this as AggregateWorkspace;
  return 'AggregateWorkspace(profileId: ${_this.profileId}, draft: ${_this.draft}, favorites: ${_this.favorites})';
}


}

/// @nodoc
abstract mixin class $AggregateWorkspaceCopyWith<$Res>  {
  factory $AggregateWorkspaceCopyWith(AggregateWorkspace value, $Res Function(AggregateWorkspace) _then) = _$AggregateWorkspaceCopyWithImpl;
@useResult
$Res call({
 int? profileId, AggregateConfig draft, Set<String> favorites
});


$AggregateConfigCopyWith<$Res> get draft;

}
/// @nodoc
class _$AggregateWorkspaceCopyWithImpl<$Res>
    implements $AggregateWorkspaceCopyWith<$Res> {
  _$AggregateWorkspaceCopyWithImpl(this._self, this._then);

  final AggregateWorkspace _self;
  final $Res Function(AggregateWorkspace) _then;

/// Create a copy of AggregateWorkspace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = freezed,Object? draft = null,Object? favorites = null,}) {
  return _then(AggregateWorkspace(
profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AggregateConfig,favorites: null == favorites ? _self.favorites : favorites // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}
/// Create a copy of AggregateWorkspace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AggregateConfigCopyWith<$Res> get draft {
  
  return $AggregateConfigCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}
}


/// Adds pattern-matching-related methods to [AggregateWorkspace].
extension AggregateWorkspacePatterns on AggregateWorkspace {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AggregateWorkspace value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AggregateWorkspace() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AggregateWorkspace value)  $default,){
final _that = this;
switch (_that) {
case _AggregateWorkspace():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AggregateWorkspace value)?  $default,){
final _that = this;
switch (_that) {
case _AggregateWorkspace() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? profileId,  AggregateConfig draft,  Set<String> favorites)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AggregateWorkspace() when $default != null:
return $default(_that.profileId,_that.draft,_that.favorites);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? profileId,  AggregateConfig draft,  Set<String> favorites)  $default,) {final _that = this;
switch (_that) {
case _AggregateWorkspace():
return $default(_that.profileId,_that.draft,_that.favorites);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? profileId,  AggregateConfig draft,  Set<String> favorites)?  $default,) {final _that = this;
switch (_that) {
case _AggregateWorkspace() when $default != null:
return $default(_that.profileId,_that.draft,_that.favorites);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AggregateWorkspace implements AggregateWorkspace {
  const _AggregateWorkspace({this.profileId, this.draft = const AggregateConfig(),  Set<String> favorites = const {}}): _favorites = favorites;
  factory _AggregateWorkspace.fromJson(Map<String, dynamic> json) => _$AggregateWorkspaceFromJson(json);

@override final  int? profileId;
@override@JsonKey() final  AggregateConfig draft;
 final  Set<String> _favorites;
@override@JsonKey() Set<String> get favorites {
  if (_favorites is EqualUnmodifiableSetView) return _favorites;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_favorites);
}


/// Create a copy of AggregateWorkspace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AggregateWorkspaceCopyWith<_AggregateWorkspace> get copyWith => __$AggregateWorkspaceCopyWithImpl<_AggregateWorkspace>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AggregateWorkspaceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AggregateWorkspace&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.draft, draft) || other.draft == draft)&&const DeepCollectionEquality().equals(other.favorites, _favorites));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,profileId,draft,const DeepCollectionEquality().hash(_favorites));
}

@override
String toString() {
    return 'AggregateWorkspace(profileId: $profileId, draft: $draft, favorites: $favorites)';
}


}

/// @nodoc
abstract mixin class _$AggregateWorkspaceCopyWith<$Res> implements $AggregateWorkspaceCopyWith<$Res> {
  factory _$AggregateWorkspaceCopyWith(_AggregateWorkspace value, $Res Function(_AggregateWorkspace) _then) = __$AggregateWorkspaceCopyWithImpl;
@override @useResult
$Res call({
 int? profileId, AggregateConfig draft, Set<String> favorites
});


@override $AggregateConfigCopyWith<$Res> get draft;

}
/// @nodoc
class __$AggregateWorkspaceCopyWithImpl<$Res>
    implements _$AggregateWorkspaceCopyWith<$Res> {
  __$AggregateWorkspaceCopyWithImpl(this._self, this._then);

  final _AggregateWorkspace _self;
  final $Res Function(_AggregateWorkspace) _then;

/// Create a copy of AggregateWorkspace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = freezed,Object? draft = null,Object? favorites = null,}) {
  return _then(_AggregateWorkspace(
profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AggregateConfig,favorites: null == favorites ? _self._favorites : favorites // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

/// Create a copy of AggregateWorkspace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AggregateConfigCopyWith<$Res> get draft {
  
  return $AggregateConfigCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}
}

// dart format on
