package com.salesmanager.core.business.utils;

import java.util.Collection;
import java.util.Collections;

import org.springframework.cache.Cache;
import org.springframework.cache.support.AbstractCacheManager;
import org.springframework.stereotype.Component;

import net.sf.ehcache.CacheManager;
import net.sf.ehcache.Ehcache;

@Component("serviceCacheManager")
public class EhCacheWrapperCacheManager extends AbstractCacheManager {

	private CacheManager cacheManager;

	public EhCacheWrapperCacheManager() {
		this.cacheManager = CacheManager.newInstance("classpath:/spring/ehcache.xml");
	}

	public EhCacheWrapperCacheManager(CacheManager cacheManager) {
		this.cacheManager = cacheManager;
	}

	@Override
	protected Cache getMissingCache(String name) {
		Ehcache ehcache = cacheManager.getEhcache(name);
		if (ehcache == null) {
			return null;
		}
		return new EhCacheWrapper(ehcache);
	}

	@Override
	protected java.util.Collection<? extends Cache> loadCaches() {
		String[] names = cacheManager.getCacheNames();
		if (names == null) {
			return Collections.emptyList();
		}
		java.util.List<Cache> caches = new java.util.ArrayList<>();
		for (String name : names) {
			Ehcache ehcache = cacheManager.getEhcache(name);
			if (ehcache != null) {
				caches.add(new EhCacheWrapper(ehcache));
			}
		}
		return caches;
	}

	@Override
	public Collection<String> getCacheNames() {
		String[] names = cacheManager.getCacheNames();
		return names == null ? Collections.emptyList() : java.util.Arrays.asList(names);
	}

	public CacheManager getCacheManager() {
		return cacheManager;
	}

	public void setCacheManager(CacheManager cacheManager) {
		this.cacheManager = cacheManager;
	}
}
