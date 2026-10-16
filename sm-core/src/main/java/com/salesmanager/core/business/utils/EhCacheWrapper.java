package com.salesmanager.core.business.utils;

import net.sf.ehcache.Ehcache;
import net.sf.ehcache.Element;

import org.springframework.cache.Cache;
import org.springframework.cache.support.SimpleValueWrapper;
import org.springframework.util.Assert;

public class EhCacheWrapper implements Cache {

	private final Ehcache ehcache;

	public EhCacheWrapper(Ehcache ehcache) {
		this.ehcache = ehcache;
	}

	@Override
	public String getName() {
		return ehcache.getName();
	}

	@Override
	public Object getNativeCache() {
		return ehcache;
	}

	@Override
	public ValueWrapper get(Object key) {
		Element element = ehcache.get(key);
		if (element == null) {
			return null;
		}
		return new SimpleValueWrapper(element.getObjectValue());
	}

	@Override
	@SuppressWarnings("unchecked")
	public <T> T get(Object key, Class<T> type) {
		Element element = ehcache.get(key);
		if (element == null) {
			return null;
		}
		Object value = element.getObjectValue();
		if (type != null && !type.isInstance(value)) {
			throw new IllegalStateException("Cached value is not of required type [" + type.getName() + "], actual value [" + value + "]");
		}
		return (T) value;
	}

	@Override
	public <T> T get(Object key, java.util.concurrent.Callable<T> callable) {
		Element element = ehcache.get(key);
		if (element != null) {
			return (T) element.getObjectValue();
		}
		try {
			T value = callable.call();
			ehcache.put(new Element(key, value));
			return value;
		} catch (Exception e) {
			throw new RuntimeException("Could not compute value for key: " + key, e);
		}
	}

	@Override
	public void put(Object key, Object value) {
		Element element = new Element(key, value);
		ehcache.put(element);
	}

	@Override
	public ValueWrapper putIfAbsent(Object key, Object value) {
		Assert.notNull(key, "key must not be null");
		Element element = new Element(key, value);
		Element old = ehcache.putIfAbsent(element);
		if (old != null) {
			return new SimpleValueWrapper(old.getObjectValue());
		}
		return null;
	}

	@Override
	public void evict(Object key) {
		ehcache.remove(key);
	}

	@Override
	public void clear() {
		ehcache.removeAll();
	}
}
