# New ports collection makefile for:	Atomia DNS database setup
# Date created:				Fri May  4 08:45:08 CEST 2012
# Whom:					Jimmy Bergman <jimmy@sigint.se>
#
# $FreeBSD$
#

PORTNAME=	atomiadns
PORTVERSION=	1.1.10
CATEGORIES=	dns
MASTER_SITES=	https://nodeload.github.com/atomia/atomiadns/tarball/
PKGNAMESUFFIX=	-database
DISTNAME=	${PORTVERSION}
EXTRACT_SUFX=

MAINTAINER=	jimmy@sigint.se
COMMENT=	The database setup part of Atomia DNS

LICENSE=	ISCL

USE_PGSQL=	yes
NO_BUILD=	yes
WRKSRC=		${WRKDIR}/atomia-atomiadns-c4e6aab

do-install:
	cd ${WRKSRC}/server && ${COPYTREE_SHARE} schema ${PREFIX}/share/atomiadns && ${CHMOD} 755 ${PREFIX}/share/atomiadns/schema/*.sh
	cd ${WRKSRC}/server && ${INSTALL_DATA} -d conf ${PREFIX}/share/atomiadns/conf
	cd ${WRKSRC}/server && ${INSTALL_DATA} conf/atomiadns.conf ${PREFIX}/share/atomiadns/conf/atomiadns-database.conf
	cd ${WRKSRC}/server && ${INSTALL_SCRIPT} debian/atomiadns-database.postinst ${PREFIX}/bin/atomiadns-sync-database

.include <bsd.port.mk>
