# $FreeBSD$

PORTNAME=	atomiadns
PORTVERSION=	1.1.42
CATEGORIES=	dns
MASTER_SITES=	http://www.atomiadns.com/tarballs/
PKGNAMESUFFIX=	-database
DISTNAME=	${PORTVERSION}

MAINTAINER=	jimmy@sigint.se
COMMENT=	Atomia DNS database setup tools and database schema

LICENSE=	ISCL

USES=		pgsql
NO_BUILD=	yes
WRKSRC=		${WRKDIR}/${PORTNAME}-${PORTVERSION}

RUN_DEPENDS	+=	sudo>=0:${PORTSDIR}/security/sudo

do-install:
	cd ${WRKSRC}/server && ${COPYTREE_SHARE} schema ${STAGEDIR}${PREFIX}/share/atomiadns && ${CHMOD} 755 ${STAGEDIR}${PREFIX}/share/atomiadns/schema/*.sh
	cd ${WRKSRC}/server && ${INSTALL_DATA} -d conf ${STAGEDIR}${PREFIX}/share/atomiadns/conf
	cd ${WRKSRC}/server && ${INSTALL_DATA} conf/atomiadns.conf ${STAGEDIR}${PREFIX}/share/atomiadns/conf/atomiadns-database.conf
	cd ${WRKSRC}/server && ${INSTALL_SCRIPT} debian/atomiadns-database.postinst ${STAGEDIR}${PREFIX}/bin/atomiadns-sync-database

.include <bsd.port.mk>
